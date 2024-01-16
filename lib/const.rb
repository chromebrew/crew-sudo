PROGNAME        = File.basename($0, '.rb')
IS_BASHRC       = ARGV.include?('--bashrc')
SOCKET_PATH     = '/tmp/crew-sudo.socket'
PID_FILE_PATH   = '/tmp/crew-sudo.pid'
DAEMON_LOG_PATH = '/tmp/crew-sudo.log'