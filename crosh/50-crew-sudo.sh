#!/bin/dash
# 50-crew-sudo.sh: Add a crosh command called "normalshell" which
#                  opens a shell without landlock/"no new privileges" restrictions

USAGE_normalshell=''

HELP_normalshell='
  Open a command line shell without landlock/"no new privileges" restrictions.
'

cmd_normalshell() (
  exec crew-sudo --client /bin/bash -l
)