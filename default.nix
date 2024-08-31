{
  coreutils,
  findutils,
  gnugrep,
  gnused,
  less,
  mpv,
  writeShellScriptBin,

  watch-later-reldir ? "default"
}:

assert builtins.isString watch-later-reldir;
assert (builtins.stringLength watch-later-reldir) > 0;

writeShellScriptBin
"lm"
''
PATH=
set \
  -o errexit \
  -o nounset \
  -o pipefail
shopt -s shift_verbose

WATCHDIR="''${XDG_STATE_HOME:-$HOME/.local/state}/lm/${watch-later-reldir}"

usage()
{
  echo "Usage: $0 [-l | -p | -r] [<1-Number of stored movies>"]
  exit $1
}

${coreutils}/bin/mkdir -p "$WATCHDIR"

[[ $# -gt 2 ]] && usage 2

OPERATION=p
LINE=

if [[ $# -ge 1 ]]
then
  if [[ -r $1 ]]
  then
    OPERATION=f
  else
    case $1 in
      (-l|-p|-r)
        OPERATION=''${1: -1}
        shift
        ;;
    esac

    if [[ $# -eq 1 ]]
    then
      if [[ $1 =~ ^[1-9][0-9]*$ ]]
      then
        LINE=$1
      else
        usage 3
      fi
    fi
  fi
fi

case $OPERATION in
  (f|l)
    ;;

  (p)
    # If we are not listing, then empty LINE means play latest video
    if [[ -z $LINE ]]
    then
      LINE=1
    fi
    ;;

  (r)
    if [[ -z $LINE ]]
    then
      echo "Remove operation must have line(s)" >&2
      usage 18
    fi
    ;;

  (*)
    echo "Unknown operation: $OPERATION" >&2
    usage 19
    ;;
esac

show_video()
{
  local video_file=$1
  shift

  exec ${mpv}/bin/mpv \
     --mute=yes \
     --pause \
     --watch-later-dir="$WATCHDIR" \
     --save-position-on-quit \
     --write-filename-in-watch-later-config \
     --watch-later-options-set=start \
     --resume-playback \
     "$video_file"
}

handle_watchfile()
{
  local watchfile="$1"
  local line=$2

  if [[ $watchfile ]]
  then
    if [[ -f $watchfile ]]
    then
      if [[ $OPERATION == r ]]
      then
        echo "Removing watch file '$watchfile' for video number: '$line'"
        ${coreutils}/bin/rm -f "$watchfile"
        exit
      fi

      local videofile="$(${gnused}/bin/sed -n "1s,^# \(.*\)$,\1,p" "$watchfile")"

      if [[ $videofile ]]
      then
        if existingvideofile="$(${coreutils}/bin/realpath -eq "$videofile")"
        then
          case $OPERATION in
            (l)
              echo "$line:''\'''${existingvideofile/\'/\'\"\'\"\'}'"
              ;;

            (p)
              show_video "$existingvideofile"
              ;;
          esac
        else
          echo "Video file '$videofile' in watchfile '$watchfile' does not exist(Video number: $line)"
          return 3
        fi
      else
        echo "No file in $watchfile(Video number: $line)"
        return 4
      fi
    fi
  else
    echo "Watch file $watchfile does not exist(video number: $line)"
    return 2
  fi
}

lswatchfiles()
{
  ${findutils}/bin/find "$WATCHDIR" -type f -print | ${findutils}/bin/xargs -r ${gnugrep}/bin/grep -L '# redirect entry' | { ${findutils}/bin/xargs -r ${coreutils}/bin/ls -t 2>&- || true; }
}

if [[ $OPERATION = f ]]
then
  show_video "$@"
elif [[ $LINE ]]
then
  CUR_WATCHFILE="$( lswatchfiles | { ${coreutils}/bin/tail -n +$LINE || true; } | ${coreutils}/bin/head -n 1 )"

  if [[ $CUR_WATCHFILE ]]
  then
    handle_watchfile "$CUR_WATCHFILE" $LINE
  else
    echo "Not that many videos remembered($LINE)"
  fi
else
  mapfile -t < <( lswatchfiles )

  NUM_FILES="''${#MAPFILE[@]}"

  for(( i=0; i<$NUM_FILES; i++))
  do
    handle_watchfile "''${MAPFILE[i]}" "$(($i+1))" || :
  done |& ${less}/bin/less
fi
''
