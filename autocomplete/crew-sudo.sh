# bash completion for crew-sudo command

function _crew-sudo () {
  # available options
  local avail_opts=(--bashrc --foreground --replace)

  # available commands
  local cmds=(client daemon stop-daemon)

  # parameter that trigger this function
  local current="${COMP_WORDS[COMP_CWORD]}"

  if [[ "${current:0:1}" == '-' ]]; then
    # match ${current} with available option list if ${current} start with '-'
    # save result to $COMPREPLY variable
    COMPREPLY=( $(compgen -W "${avail_opts[*]}" -- "${current}") )
  elif [[ ${COMP_CWORD} == 1 ]]; then
    # match ${current} with command list if ${current} is the first argument
    COMPREPLY=( $(compgen -W "${cmds[*]}" -- "${current}") )
  else
    return 1
  fi
}

# register this function as completion function for crew-sudo command
complete -F _crew-sudo crew-sudo