#!/bin/bash -eu
if [ -n "${CREW_DEST_PREFIX}" ]; then
  INSTALL_PREFIX="${CREW_DEST_PREFIX}"
else
  : "${INSTALL_PREFIX:=/usr/local}"
fi

mkdir -p ${INSTALL_PREFIX} ${INSTALL_PREFIX}/{lib,bin}

cp -r . ${INSTALL_PREFIX}/lib/crew-sudo

ln -sf ../lib/crew-sudo/crew-sudo ${INSTALL_PREFIX}/bin/crew-sudo
ln -sf ../lib/crew-sudo/crew-sudo ${INSTALL_PREFIX}/bin/sudo

if [ -d ${INSTALL_PREFIX}/etc/env.d ]; then
  # installing under chromebrew
  mkdir -p ${INSTALL_PREFIX}/etc/{env.d,bash.d}
  ln -sf ../lib/crew-sudo/autostart/crew-sudo.sh ${INSTALL_PREFIX}/etc/env.d/crew_sudo
  ln -sf ../lib/crew-sudo/autocomplete/crew-sudo.sh ${INSTALL_PREFIX}/etc/bash.d/crew_sudo
else
  # installing without chromebrew, append the autostart script to bashrc
  echo "source ${INSTALL_PREFIX}/lib/crew-sudo/autostart/crew-sudo.sh" >> ~/.bashrc
  echo -e '\e[1;32m''crew-sudo installed!''\e[0m'
fi