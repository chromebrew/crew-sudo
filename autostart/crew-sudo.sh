if [[ "$(< "/proc/$(ps -p $PPID -o ppid=)/cmdline")" == /sbin/frecon* ]]; then
  # start crew-sudo daemon if running in VT-2
  [ -f /tmp/crew-sudo.socket ] || crew-sudo --daemon
fi