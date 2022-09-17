#!/usr/bin/env bash

# Installation base dir
CONF="/opt/unbound"
FNAME="unbound.cache"

usage ()
{
  # shellcheck disable=SC2086
  echo "Usage: $(basename $0) [-s | -l | -r | -h] [filename]"
  echo ""
  echo "l - Load: Load Unbound DNS cache from file"
  echo "s - Save: Save Unbound DNS cache contents to plain file with domain names"
  echo "r - Reload: Saves the Unbound DNS cache, reloads the server, then loads the cache"
  echo "h - This screen"
  echo "filename - File to save/load dumped cache. If not specified, ${CONF}/${FNAME} will be used instead."
  echo "Note: Loads cache if no arguments are specified."
  echo "      Also, unbound-control must be configured."
  exit 0
}

root_check ()
{
  # shellcheck disable=SC2046
  if [ ! $(id | cut -f1 -d" ") = "uid=0(root)" ]; then
    echo "ERROR: You must be super-user to run this script"
    exit 1
  fi
}

check_saved_file ()
{
  filename=$1
  if [ -n "$filename" ] && [ ! -f "$filename" ]; then
    echo ""
    echo "ERROR: File $filename does not exist. Save it first."
    exit 3
  elif [ ! -f "${CONF}/${FNAME}" ]; then
    echo ""
    echo "ERROR: File ${CONF}/${FNAME} does not exist. Save it first."
    exit 4
  fi
}

save_cache ()
{
  # Save unbound cache
  filename=$1
  if [ -z "$filename" ]; then
    echo "Saving cache to ${CONF}/${FNAME}"
    unbound-control dump_cache > ${CONF}/${FNAME}
  else
    echo "Saving cache to $filename"
    unbound-control dump_cache > "$filename"
  fi
  echo "ok"
}

load_cache ()
{
 # Load saved cache contents and warmup cache
 filename=$1
  if [ -z "$filename" ]; then
    echo "Loading cache from ${CONF}/${FNAME}"
    check_saved_file "$filename"
    cat ${CONF}/${FNAME} | unbound-control load_cache
  else
    echo "Loading cache from $filename"
    check_saved_file "$filename"
    cat "$filename" | unbound-control load_cache
  fi
}

reload_cache ()
{
  # Reload and refresh existing cache and saved dump
  filename=$1
  save_cache "$filename"
  echo "Reloading unbound server"
  unbound-control reload
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
  set -- $(getopt --options sSlLrRhH --longoptions=save,load,reload,help -- "$arg_list") || exit 5

  # Read arguments
  for i in $(getopt --options :sSlLrRhH --longoptions=save,load,reload,help -- "$arg_list")
    do
      case $i in
        -s | -S | --save) choice="save";;
        -l | -L | --load) choice="load";;
        -r | -R | --reload) choice="reload";;
        -h | -H | --help | \?) usage;;
        -- ) ;;
        *)
          if [ "$choice" = "" ]; then
            echo "ERROR: An argument must be preceded by a flag. See -h."
            exit 8
          else
            file=$(echo "$i" | xargs)
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
