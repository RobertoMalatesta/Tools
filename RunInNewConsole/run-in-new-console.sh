#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


VERSION_NUMBER="1.01"
SCRIPT_NAME="run-in-new-console.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script runs the given shell command in a new console window.

You would normally use this tool to start interactive programs
like gdb. Another example would be to start a socat connection to
a serial port and leave it in the background for later use.

The command is passed as a string and is executed with "bash -c".

Syntax:
  $SCRIPT_NAME <options...> [--] "shell command to run"

Options:
 --terminal-type=xxx  Use the given terminal emulator, defaults to 'konsole'
                      (the only implemented type at the moment).
 --konsole-title="my title"
 --konsole-icon="icon name"  Icons are normally .png files on your system.
                             Examples are kcmkwm or applications-office.
 --konsole-no-close          Keep the console open after the command terminates.
                             Useful mainly to see why the command is failing.
 --konsole-discard-stderr    Sometimes Konsole spits out too many errors or warnings.
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Usage example, as you would manually type it:
  ./$SCRIPT_NAME "bash"

From a script you would normally use it like this:
  /path/$SCRIPT_NAME -- "\$CMD"

Exit status: 0 means success. Any other value means error.

If you wish to contribute code for other terminal emulators, please drop me a line.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license ()
{
cat - <<EOF

Copyright (c) 2014 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

EOF
}


process_long_option ()
{
  case "${opt}" in
    help)
        display_help
        exit 0
        ;;
    version)
        echo "$VERSION_NUMBER"
        exit 0
        ;;
    license)
        display_license
        exit 0
        ;;
    terminal-type)
        if [[ ${OPTARG:-} = "" ]]; then
          abort "The --terminal-type option has an empty value.";
        fi
        TERMINAL_TYPE="$OPTARG"
        ;;
    konsole-title)
        if [[ ${OPTARG:-} = "" ]]; then
          abort "The --konsole-title option has an empty value.";
        fi
        KONSOLE_TITLE="$OPTARG"
        ;;
    konsole-icon)
        if [[ ${OPTARG:-} = "" ]]; then
          abort "The --konsole-icon option has an empty value.";
        fi
        KONSOLE_ICON="$OPTARG"
        ;;
    konsole-no-close)
        KONSOLE_NO_CLOSE=1
        ;;
    konsole-discard-stderr)
        KONSOLE_DISCARD_SDTDERR=1
        ;;
    *)  # We should actually never land here, because get_long_opt_arg_count() already checks if an option is known.
        abort "Unknown command-line option \"--${opt}\".";;
  esac
}


process_short_option ()
{
  case "${opt}" in
    *) abort "Unknown command-line option \"-$OPTARG\".";;
  esac
}


get_long_opt_arg_count ()
{
  if ! test "${USER_LONG_OPT_SPEC[$1]+string_returned_if_exists}"; then
    abort "Unknown command-line option \"--$1\"."
  fi

  OPT_ARG_COUNT=USER_LONG_OPT_SPEC[$1]
}


parse_command_line_arguments ()
{
  # The way command-line arguments are parsed below was originally described on the following page,
  # although I had to make a few of amendments myself:
  #   http://mywiki.wooledge.org/ComplexOptionParsing

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  # The rest are user-defined short options.
  MY_OPT_SPEC=":-:$USER_SHORT_OPTIONS_SPEC"

  while getopts "$MY_OPT_SPEC" opt; do
    case "${opt}" in
      -)  # This case triggers for options beginning with a double hyphen ('--').
          # If the user specified "--longOpt"   , OPTARG is then "longOpt".
          # If the user specified "--longOpt=xx", OPTARG is then "longOpt=xx".
          if [[ "${OPTARG}" =~ .*=.* ]]  # With this "--key=value" format, only one argument is possible. See alternative below.
          then
            opt=${OPTARG/=*/}
            get_long_opt_arg_count "$opt"
            if (( OPT_ARG_COUNT != 1 )); then
              abort "Option \"--$opt\" expects $OPT_ARG_COUNT argument(s)."
            fi
            OPTARG=${OPTARG#*=}
          else  # With this "--key value1 value2" format, multiple arguments are possible.
            opt="$OPTARG"
            get_long_opt_arg_count "$opt"
            OPTARG=(${@:OPTIND:$OPT_ARG_COUNT})
            ((OPTIND+=$OPT_ARG_COUNT))
          fi
          process_long_option
          ;;
      *) process_short_option;;
    esac
  done

  shift $((OPTIND-1))
  ARGS=("$@")
}


# ------- Entry point -------

# Notes kept about an alternative method to set the console title with Konsole:
#
# Help text for --konsole-title:
#   Before using this option, manually create a Konsole
#   profile called "$SCRIPT_NAME", where the "Tab title
#   format" is set to %w . You may want to untick
#   global option "Show application name on the titlebar"
#   too.
#
# Code to set the window title with an escape sequence:
#  # Warning: The title does not get properly escaped here. If it contains console escape sequences,
#  #          this will break.
#  if [[ $KONSOLE_TITLE != "" ]]; then
#    CMD3+="printf \"%s\" \$'\\033]30;$KONSOLE_TITLE\\007' && "
#  fi
#
# Code to select the right Konsole profile:
#   KONSOLE_CMD+=" --profile $SCRIPT_NAME"


USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments a long option expects.
# All known options must be listed, even those with 0 arguments. Otherwise,
# the logic would generate a confusing "expects 0 arguments" error for an unknown
# option like this: --unknown=123.
declare -A USER_LONG_OPT_SPEC=([help]=0 [version]=0 [license]=0)
USER_LONG_OPT_SPEC+=([konsole-discard-stderr]=0 [konsole-no-close]=0 )
USER_LONG_OPT_SPEC+=([terminal-type]=1 [konsole-title]=1 [konsole-icon]=1)

TERMINAL_TYPE="konsole"
KONSOLE_TITLE=""
KONSOLE_ICON=""
KONSOLE_NO_CLOSE=0
KONSOLE_DISCARD_SDTDERR=0

parse_command_line_arguments "$@"

case "${TERMINAL_TYPE}" in
  konsole) : ;;
  *) abort "Unknown terminal type \"$TERMINAL_TYPE\".";;
esac

if [ ${#ARGS[@]} -ne 1 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

CMD_ARG="${ARGS[0]}"

CMD2="$(printf "%q" "$CMD_ARG")"

CMD3="echo $CMD2 && eval $CMD2"

# Running the command with "sh -c" made it crash on my PC when pressing Ctrl+C under Kubuntu 14.04.
CMD4="$(printf "bash -c %q" "$CMD3")"

KONSOLE_CMD="konsole --nofork"

if [[ $KONSOLE_TITLE != "" ]]; then
  KONSOLE_CMD+=" -p tabtitle=\"$KONSOLE_TITLE\""
fi

if [[ $KONSOLE_ICON != "" ]]; then
  KONSOLE_CMD+=" -p Icon=$KONSOLE_ICON"
fi

if [ $KONSOLE_NO_CLOSE -ne 0 ]; then
  KONSOLE_CMD+=" --noclose"
fi

KONSOLE_CMD+=" -e $CMD4"

if [ $KONSOLE_DISCARD_SDTDERR -ne 0 ]; then
  KONSOLE_CMD+=" 2>/dev/null"
fi

if false; then
  echo "KONSOLE_CMD: $KONSOLE_CMD"
fi

eval "$KONSOLE_CMD"
