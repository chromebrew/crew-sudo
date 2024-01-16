require 'socket'
require 'json'
require_relative '../lib/const'
require_relative '../lib/function'
require_relative '../lib/pty_helper'

def runas_daemon(argv)
  $mode = :daemon

  if File.exist?(SOCKET_PATH) && File.exist?(PID_FILE_PATH)
    if ARGV.include?('--replace')
      Process.kill('TERM', File.read(PID_FILE_PATH).to_i)
    else
      if IS_BASHRC
        warn "crew-sudo: Daemon started with PID #{File.read(PID_FILE_PATH)}"
      else
        message <<~EOT, loglevel: error
          crew-sudo daemon (process #{File.read(PID_FILE_PATH)}) is already running.

          Use `#{PROGNAME} --daemon --replace` to replace the running daemon
        EOT
      end
      exit 1
    end
  end

  @server = UNIXServer.new(SOCKET_PATH) # create unix socket

  # fix permission if we are running as root
  File.chown(0, 1000, SOCKET_PATH) if Process.euid.zero?
  File.chmod(0o660, SOCKET_PATH)

  # daemonize
  unless ARGV.include?('--foreground')
    Process.daemon(false, true)

    # redirect output to log
    $log = File.open(DAEMON_LOG_PATH, 'w')

    $stdin.reopen('/dev/null')
    $stdout.reopen($log)
    $stderr.reopen($log)

    [$log, $stdout, $stderr].each {|io| io.sync = true }
  end

  Process.setproctitle('crew-sudo daemon process')
  File.write(PID_FILE_PATH, Process.pid)

  warn "crew-sudo: Daemon started with PID #{Process.pid}"

  if Process.uid.zero?
    message 'Daemon running with root permission.'
  else
    message "Daemon running under UID #{Process.uid}."
  end

  message "Started with PID #{Process.pid}"

  Socket.accept_loop(@server) do |socket, _|
    client_pid, client_uid, client_gid = socket.getsockopt(:SOL_SOCKET, :SO_PEERCRED).unpack('L*')

    unless client_uid == 1000
      message "Request from PID #{client_pid} rejected (only chronos user is allowed)"
      socket.close
      next
    end

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

      message "Process #{pid} spawned by client (#{client_pid}): #{cmdline}"
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
  @server&.close
  File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)
  File.delete(PID_FILE_PATH) if File.exist?(PID_FILE_PATH)
end
