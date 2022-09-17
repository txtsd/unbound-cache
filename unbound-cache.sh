#!/usr/bin/env bash

# Installation base dir
CONF="/opt/unbound"
FNAME="unbound.cache"

# Unbound binaries
UC=$(which unbound-control) || exit 7
UCS=$(which unbound-control-setup) || exit 7

# OS utilities
BASENAME=$(which basename) || exit 6
CAT=$(which cat) || exit 6
CUT=$(which cut) || exit 6
ECHO=$(which echo) || exit 6
GETOPT=$(which getopt) || exit 6
ID=$(which id) || exit 6
XARGS=$(which xargs) || exit 6

usage ()
{
  # shellcheck disable=SC2086
  $ECHO "Usage: $($BASENAME $0) [-s | -l | -r | -h] [filename]"
  $ECHO ""
  $ECHO "l - Load: Load Unbound DNS cache from file"
  $ECHO "s - Save: Save Unbound DNS cache contents to plain file with domain names"
  $ECHO "r - Reload: Saves the Unbound DNS cache, reloads the server, then loads the cache"
  $ECHO "h - This screen"
  $ECHO "filename - File to save/load dumped cache. If not specified, ${CONF}/${FNAME} will be used instead."
  $ECHO "Note: Loads cache if no arguments are specified."
  $ECHO "      Also, unbound-control must be configured."
  exit 0
}

root_check ()
{
  # shellcheck disable=SC2046
  if [ ! $($ID | $CUT -f1 -d" ") = "uid=0(root)" ]; then
    $ECHO "ERROR: You must be super-user to run this script"
    exit 1
  fi
}

check_saved_file ()
{
  filename=$1
  if [ -n "$filename" ] && [ ! -f "$filename" ]; then
    $ECHO ""
    $ECHO "ERROR: File $filename does not exist. Save it first."
    exit 3
  elif [ ! -f "${CONF}/${FNAME}" ]; then
    $ECHO ""
    $ECHO "ERROR: File ${CONF}/${FNAME} does not exist. Save it first."
    exit 4
  fi
}

save_cache ()
{
  # Save unbound cache
  filename=$1
  if [ -z "$filename" ]; then
    $ECHO "Saving cache to ${CONF}/${FNAME}"
    $UC dump_cache > ${CONF}/${FNAME}
  else
    $ECHO "Saving cache to $filename"
    $UC dump_cache > "$filename"
  fi
  $ECHO "ok"
}

load_cache ()
{
 # Load saved cache contents and warmup cache
 filename=$1
  if [ -z "$filename" ]; then
    $ECHO "Loading cache from ${CONF}/${FNAME}"
    check_saved_file "$filename"
    $CAT ${CONF}/${FNAME} | $UC load_cache
  else
    $ECHO "Loading cache from $filename"
    check_saved_file "$filename"
    $CAT "$filename" | $UC load_cache
  fi
}

reload_cache ()
{
  # Reload and refresh existing cache and saved dump
  filename=$1
  save_cache "$filename"
  $ECHO "Reloading unbound server"
  $UC reload
  load_cache "$filename"
}


# Root check
root_check

# Check command-line arguments
arg_list=$*
if [ "$*" = "" ]; then
  # Load cache if there are no arguments
  load_cache
else
  # Parse command line
  # shellcheck disable=SC2046
  set -- $($GETOPT --options sSlLrRhH --longoptions=save,load,reload,help -- "$arg_list") || exit 5

  # Read arguments
  for i in $($GETOPT --options :sSlLrRhH --longoptions=save,load,reload,help -- "$arg_list")
    do
      case $i in
        -s | -S | --save) choice="save";;
        -l | -L | --load) choice="load";;
        -r | -R | --reload) choice="reload";;
        -h | -H | --help | \?) usage;;
        -- ) ;;
        *)
          if [ "$choice" = "" ]; then
            $ECHO "ERROR: An argument must be preceded by a flag. See -h."
            exit 8
          else
            file=$(echo "$i" | $XARGS)
            break
          fi;;
      esac
    done
fi

if [ "$choice" = "save" ]; then
  save_cache "$file"
elif [ "$choice" = "load" ]; then
  load_cache "$file"
elif [ "$choice" = "reload" ]; then
  reload_cache "$file"
fi

exit 0
