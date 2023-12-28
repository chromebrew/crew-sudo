#!/bin/bash -eu

if [ ${EUID} != 0 ] && [ ! -w ${INSTALL_PREFIX} ]; then
  echo "Please run this script as root." 2>&1
  exit 1
fi

INSTALL_PREFIX="${CREW_PREFIX:-/usr/local}"

cp -r . ${INSTALL_PREFIX}/lib/crew-sudo

ln -s ../lib/crew-sudo/crew-sudo ${INSTALL_PREFIX}/bin/crew-sudo
ln -s ../lib/crew-sudo/crew-sudo ${INSTALL_PREFIX}/bin/sudo

if [ -d ${INSTALL_PREFIX}/etc/env.d ]; then
  # installing under chromebrew
  ln -s ../lib/crew-sudo/autostart/crew-sudo.sh ${INSTALL_PREFIX}/etc/env.d/crew_sudo
else
  # installing without chromebrew, append the autostart script to bashrc
  echo "source ${INSTALL_PREFIX}/lib/crew-sudo/autostart/crew-sudo.sh" > ~/.bashrc
fi