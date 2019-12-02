#!/usr/bin/env bash
# This pass plugin tries to find a matching password file for a given URL Using
# pass-url can help avoid phishing as an incorrect URL won't match, which will
# alert you
#
# We first try to parse the input as a URL (being *very* lenient, occasionally
# getting garbage hosts). We then try to match the host + path and make the URL
# more and more generic until we either find a match or run out of
# simplifications.
#
# - First we remove ending path, going from https://example.com/foo/bar to
# https://example.com/foo
# - Then we remove starting subdomains, going from https://sub.example.com to
# https://example.com

set -eu -o pipefail

declare usage="Usage $PROGRAM $COMMAND [--clip[=line-number],-c[line-number]] [--force-any-scheme,-f] URL"

declare clip=0 opts selected_line=1
opts="$($GETOPT -o c::fh -l clip::,force-any-scheme,help -n "$PROGRAM" -- "$@")"
declare err=$?
if [[ $err -ne 0 ]]; then
  die ""
fi

eval set -- "$opts"
while true; do case $1 in
  # Copy to clipboard (NOTE: we don't support line number at this point)
  -c|--clip) clip=1; selected_line="${2:-1}"; shift 2;;
  # Ignore non-HTTPS scheme
  -f|--force-any-scheme) PASS_URL_IGNORE_NON_HTTPS=1; shift ;;
  -h|--help) echo "$usage"; exit 0 ;;
  --) shift; break ;;
esac done

if (( $# != 1 )); then
  die "Error: $usage"
fi

declare -r url="$1"
# From Wikipedia at https://en.wikipedia.org/wiki/URL
# URL scheme:(//(user@)?host?(:port)?(/path)?(\?query)?(#fragment)?
declare -r scheme_re='[[:alpha:]][[:alpha:][:digit:].+-]*'
# The following regexes are overly lax: anything but the next delimiter
declare -r user_re='[^@]+'
declare -r host_re='[^/:]+'
declare -r port_re='[[:digit:]]+'
declare -r path_re='/[^?]+'
declare -r query_re='[^#]+'
declare -r fragment_re='.+'
declare -r url_re="^(($scheme_re):)?(//)?(($user_re)@)?($host_re)(:($port_re))?($path_re)?(\?($query_re))?(#($fragment_re))?"

if [[ $url =~ $url_re ]]; then
  # Extract the match for each part of the url
  declare -r scheme_match=${BASH_REMATCH[2]} # without trailing :// or :
  declare -r host_match=${BASH_REMATCH[6]}
  declare -r path_match=${BASH_REMATCH[9]} # with leading /
  # Uncomment to use as part of matching algorithm
  # declare -r user_match=${BASH_REMATCH[5]}
  # declare -r port_match=${BASH_REMATCH[8]}
  # declare -r query_match=${BASH_REMATCH[11]} # without leading ?
  # declare -r fragment_match=${BASH_REMATCH[13]} # without leading #

  # Uncomment to debug the regex
  # for (( i = 0; i <= ${#BASH_REMATCH}; i++)); do
  #   echo $i ${BASH_REMATCH[i]}
  # done

  # Error out if the page is not HTTPS (could be MITM or just plain insecure)
  # We may want to accept file, http for localhost, sftp?
  if [[ $scheme_match != "https" && -z ${PASS_URL_IGNORE_NON_HTTPS:-""} ]]
  then
    die "Error: URL scheme is not HTTPs. This may be the wrong site or insecure! -f to ignore"
  fi

  declare host_to_try=$host_match
  declare path_to_try=$path_match

  # First, try to match full host + full path 
  # (path as directories/file under a directory for the URL)
  while declare file_to_try="$host_to_try$path_to_try"; [[ -n "$file_to_try" ]]
  do
    declare passfile="$PREFIX/$file_to_try.gpg"
    check_sneaky_paths "$file_to_try"

    if [[ -f $passfile ]]; then
      head="$($GPG -d "${GPG_OPTS[@]}" "$passfile" | tail -n "+${selected_line}" | head -n 1 || exit $?)"
      if [[ $clip -ne 0 ]]; then
        [[ $selected_line =~ ^[0-9]+$ ]] || die "Clip location '$selected_line' is not a number."
        [[ -n $head ]] || die "There is no password to put on the clipboard at line ${selected_line}."
        clip "$head" "$file_to_try (for $url)"
      else
        echo "$head"
      fi
      exit 0
    elif [[ $path_to_try =~ / ]]; then
      # Remove last path segment to try to match on more generic URL
      path_to_try=${path_to_try%/*}
    elif [[ $host_to_try =~ \. ]]; then
      # Remove first subdomain fragment to try to match on more generic URL
      host_to_try=${host_to_try#*.}
    else
      die "Error: a password for $url was not found in the password store."
    fi
  done
  die "Error: a password for $url was not found in the password store."
else
  # This should essentially *never* happen given our lax regex
  die "Could not match $url as a URL"
fi
