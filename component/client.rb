require 'socket'
require 'io/console'
require 'json'
require_relative '../lib/const'
require_relative '../lib/function'

def restore_console
  # restore_console: restore tty attributes
  system('/bin/stty', $tty_attr, exception: true)
end

def runas_client(argv)
  $mode     = :client
  is_tty    = $stdin.isatty && $stdout.isatty && $stderr.isatty
  $tty_attr = %x[/bin/stty -g].chomp if is_tty
  socket    = UNIXSocket.open(SOCKET_PATH) # connect to daemon

  # send stdin/stdout/stderr to daemon
  [$stdin, $stdout, $stderr].each {|io| socket.send_io(io) }

  # let daemon to take over stdin
  $stdin.close

  send_event(socket, 'sudoRequest', {
    arg:      argv,
    env:      ENV.to_h,
    cwd:      Dir.pwd,
    termSize: IO.console.winsize
  })

  # listen to terminal resize event
  trap('WINCH') { send_event(socket, 'termResize', { newsize: IO.console.winsize }) } if is_tty

  # ignore following signals
  %w[HUP PIPE QUIT TERM INT].each {|sig| trap(sig) {} }

  # listen to client events
  until socket.closed?
    data = socket.gets
    next unless data

    event = JSON.parse(data, symbolize_names: true)

    case event[:event]
    when 'cmdSpawned' # command executed
      message "Process #{event[:pid]} spawned"

      # disable terminal echo
      system('/bin/stty', 'raw', '-echo') if is_tty
    when 'cmdKilledBySignal' # process exited because of signal
      # restore tty attributes on program exit
      restore_console if is_tty

      message "Process killed with SIG#{Signal.list.key(event[:signal])} (signal #{event[:signal]})"
      exit(128 + event[:signal])
    when 'cmdExited' # process exited normally
      # restore tty attributes on program exit
      restore_console if is_tty

      message "Process exited with status #{event[:exitstatus]}"
      exit(event[:exitstatus])
    end
  end
rescue Errno::ENOENT
  message <<~EOT, loglevel: :warning
    Cannot connect to crew-sudo daemon, is the daemon running?

    Hint: Enter VT-2 shell by pressing Ctrl + Alt + ->, the daemon will start
          automatically after you log in with user 'chronos'
  EOT

  exit(1)
ensure
  restore_console if is_tty
  socket&.close
end