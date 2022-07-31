#!/bin/bash

# This script saves the Trello board with attachments to the given
# directory, using the cookie file.
# Copyright (C) 2022, Slava <freeprogs.feedback@yandex.ru>

progname=`basename $0`

# Print an error message to stderr
# error(str)
error()
{
    echo "error: $progname: $1" >&2
}

# Print a message to stdout
# msg(str)
msg()
{
    echo "$progname: $1"
}

# Print a message to a log file
# log(file, str)
log()
{
    local ofpath="$1"
    local message="$2"

    echo "$message" >>"$ofpath"
}

# Print program usage to stderr
# usage()
usage()
{
    echo "Try \`$progname --help' for more information." >&2
}

# Print program help info to stderr
# help_info()
help_info()
{
    {
        echo "usage: $progname url outputdir cookiefile"
        echo ""
        echo "Save the Trello board with attachments to the given directory."
        echo ""
        echo "  To get the cookie-file, open your Trello account in the browser,"
        echo "  open developer tools in the browser, take the cookie header value"
        echo "  and save this value to the cookie file without the header name."
        echo ""
        echo "Example:"
        echo ""
        echo "  $progname https://trello.com/b/aBCdEf abcdef cookie.txt"
        echo ""
        echo "  It will save to directory abcdef file abcdef.json and all attachments"
        echo "  with the card id and the file id of every attachment file found in"
        echo "  file abcdef.json."
        echo ""
    } >&2
}

load_trello_board()
{
    local url=$1
    local odname=$2
    local ifpath_cookie=$3
    local ofname
    local ifname_attach
    local odname_attach

    ofname="${odname}.json"
    ifname_attach=$ofname
    odname_attach=$odname

    make_output_directory "$odname" || {
        error "Can't make output directory $odname"
        return 1
    }
    msg "Download json to $odname/$ofname ..."
    load_trello_board_json "$url" "$odname/$ofname" "$ifpath_cookie" || {
        error "Can't load $url to $odname/$ofname with cookie from $ifpath_cookie"
        return 1
    }
    msg "Ok"
    msg "Download attachments to $odname ..."
    load_trello_board_attachments \
        "$odname/$ifname_attach" \
        "$odname_attach" \
        "$ifpath_cookie" || {
        error "Can't load $url to $odname with cookie from $ifpath_cookie"
        return 1
    }
    msg "Ok"
    return 0
}

make_output_directory()
{
    local dname=$1

    mkdir "$dname" 2>/dev/null
}

load_trello_board_json()
{
    local url="${1}.json"
    local ofpath=$2
    local ifpath_cookie=$3
    local cookie_data

    cookie_data=`cat "$ifpath_cookie"`
    raw_download_board "$url" "$ofpath" "$cookie_data" || return 1
    return 0
}

raw_download_board()
{
    local url=$1
    local ofpath=$2
    local cookie_data=$3

    curl -s -b "$cookie_data" -o "$ofpath" "$url" || return 1
    return 0
}

load_trello_board_attachments()
{
    local ifpath_attach=$1
    local odname=$2
    local ifpath_cookie=$3
    local ofname_attach_data="attachments_data.tmp"

    make_attachments_data "$ifpath_attach" "$ofname_attach_data" "$odname" || {
        error "Can't make attachments data from $ifpath_attach"
        return 1
    }
    load_from_attachments_data "$odname/$ofname_attach_data" "$odname" "$ifpath_cookie" || {
        error "Can't load attachments $odname/$ofname_attach_data to $odname"
        return 1
    }
    remove_attachments_data "$odname/$ofname_attach_data" || {
        error "Can't remove attachments data $odname/$ofname_attach_data"
        return 1
    }
    return 0
}

make_attachments_data()
{
    local ifname=$1
    local ofname=$2
    local odname=$3

    echo "make_attachments_data() $ifname $ofname $odname"
    return 0
}

load_from_attachments_data()
{
    local ifpath=$1
    local odname=$2
    local ifpath_cookie=$3

    echo "load_from_attachments_data() $ifpath $odname $ifpath_cookie"
    return 0
}

remove_attachments_data()
{
    local ifpath=$1

    echo "remove_attachments_data() $ifpath"
    return 0
}

main()
{
    local url
    local outdir
    local cookiefile

    case $# in
      0)
        usage
        return 1
        ;;
      1)
        [ "$1" = "--help" ] && {
            help_info
            return 1
        }
        ;;
      3)
        usage
        url=$1
        outdir=$2
        cookiefile=$3
        load_trello_board "$url" "$outdir" "$cookiefile" || return 1
        ;;
      *)
        error "unknown arglist: \"$*\""
        return 1
        ;;
    esac
    return 0
}

main "$@" || exit 1

exit 0
