if grep -q '^/sbin/frecon' < "/proc/$(ps -p $PPID -o ppid= | tr -d ' ')/cmdline"; then
  # start crew-sudo daemon if running in VT-2
  [ -f /tmp/crew-sudo.socket ] || crew-sudo --daemon --bashrc
fi