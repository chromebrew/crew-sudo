require 'socket'
require 'json'
require_relative '../lib/const'
require_relative '../lib/function'
require_relative '../lib/pty_helper'

def runas_daemon(argv)
  $mode = :daemon

  # daemonize
  Process.daemon(false, true) unless ARGV.include?('--foreground')

  Process.setproctitle('crew-sudo daemon process')

  warn "crew-sudo: Daemon started with PID #{Process.pid}"

  # redirect output to log
  $log = File.open(DAEMON_LOG_PATH, 'w')

  $stdin.reopen('/dev/null')
  $stdout.reopen($log)
  $stderr.reopen($log)

  [$log, $stdout, $stderr].each {|io| io.sync = true }

  if Process.uid.zero?
    message 'Daemon running with root permission.'
  else
    message "Daemon running under UID #{Process.uid}."
  end

  message "Started with PID #{Process.pid}"

  # create unix socket
  @server = UNIXServer.new(SOCKET_PATH)
  File.chmod(0o660, SOCKET_PATH)

  # fix permission if we are running as root
  File.chown(0, 1000, SOCKET_PATH) if Process.uid.zero?

  Socket.accept_loop(@server) do |socket, _|
    Thread.new do
      # receive client's stdin/stdout/stderr io from client
      client_stdin, client_stdout, client_stderr = [socket.recv_io, socket.recv_io, socket.recv_io]

      client_request = JSON.parse(socket.gets, symbolize_names: true)
      cmdline        = ['/usr/bin/sudo'].concat(client_request[:arg])
      open_pty       = client_stdin.isatty && client_stdout.isatty && client_stderr.isatty
      process_env    = client_request[:env].transform_keys(&:to_s)

      if open_pty
        # if client's stdout is a tty (not a pipe/file), create a pty for process
        # forward client input to pty + pty output to client
        pty = PTYHelper.new(client_stdin, client_stdout, termSize: client_request[:termSize])
        pid = pty.run_command(*cmdline, cwd: client_request[:cwd], env: process_env)
      else
        # attach to stdin/stdout/stderr of client directly
        pid = spawn process_env, *cmdline,
            in:    client_stdin,
            out:   client_stdout,
            err:   client_stderr,
            chdir: client_request[:cwd]
      end

      message "Process #{pid} spawned: #{cmdline}"
      send_event(socket, 'cmdSpawned', { pid: pid })

      # listen to client events
      event_thread = Thread.new do
        until socket.closed?
          event = JSON.parse(socket.gets, symbolize_names: true)

          case event[:event]
          when 'termResize' # when client's terminal resized
            if open_pty
              rows, cols = event[:newsize]

              message "Resize terminal to #{rows} rows, #{cols} cols"
              message "Sending TIOCSWINSZ loctl to PTY..."

              # set pty size
              pty.resize(rows, cols)
            end
          end
        end
      end

      # wait for process exit and send the exit status back to client
      Process.waitpid(pid)

      if $?.signaled?
        message "Process #{pid} killed with SIG#{Signal.list.key($?.termsig)} (signal #{$?.termsig})"
        send_event(socket, 'cmdKilledBySignal', { signal: $?.termsig })
      else
        message "Process #{pid} exited with status #{$?.exitstatus}"
        send_event(socket, 'cmdExited', { exitstatus: $?.exitstatus })
      end
    ensure
      pty.close if open_pty

      Thread.kill(event_thread)
      [client_stdin, client_stdout, client_stderr, socket].each(&:close)
    end
  end
ensure
  @server.close
  File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)
end