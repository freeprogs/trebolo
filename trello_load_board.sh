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

# Load the Trello board by the board url to the given directory, using
# the cookie file
# load_trello_board(boardurl, outdir, cookiefile)
# args:
#   boardurl - The url of board on trello.com
#   outdir - The output directory
#   cookiefile - The file with a value for the cookie HTTP-header
# return:
#   0 - If success
#   1 - If any error
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

    mkdir "$dname" 2>/dev/null || return 1
    return 0
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
    local otname_stage1="$ofname.stage1"

    cat "$ifname" | python3 -c '
import sys
import json

doc = json.loads(sys.stdin.read())
cards = doc["cards"]
all_attachments = [i["attachments"] for i in cards
                   if "attachments" in i and i["attachments"]]
for attachments in all_attachments:
    attachments_clean = [i for i in attachments
                         if "fileName" in i and i["fileName"]]
    for i in attachments_clean:
        fileid = i["id"]
        url = i["url"]
        filename = i["name"]
        print(fileid, url, filename)
'   >"$odname/$otname_stage1" || return 1

    cat "$odname/$otname_stage1" | awk '
{
    file_id = $1
    url = $2
    file_name = $3
    card_id = get_idcard($2)
    file_bigname = card_id "_" file_id "_" file_name
    print url, file_bigname
}

function get_idcard(url,   i1, i2, out) {
    i1 = index(url, "/cards/") + length("/cards/")
    i2 = index(url, "/attachments/")
    out = substr(url, i1, i2 - i1)
    return out
}
'   >"$odname/$ofname" || return 1

    rm -rf "$odname/$otname_stage1" || return 1

    return 0
}

load_from_attachments_data()
{
    local ifpath=$1
    local odname=$2
    local ifpath_cookie=$3
    local cookie_data
    local url
    local ofname

    cookie_data=`cat "$ifpath_cookie"`
    cat "$ifpath" | while read line; do
        url=`echo "$line" | attachments_data_get_field 1`
        ofname=`echo "$line" | attachments_data_get_field 2`
        raw_download_attachment \
            "$url" \
            "$odname/$ofname" \
            "$cookie_data" || {
            error "Can't download attachment from $url"
            return 1
        }
    done
    return 0
}

attachments_data_get_field()
{
    local field_number=$1

    awk '{print $'"$field_number"';}'
}

raw_download_attachment()
{
    local url=$1
    local ofpath=$2
    local cookie_data=$3

    curl -s -b "$cookie_data" -o "$ofpath" "$url" || return 1
    return 0
}

remove_attachments_data()
{
    local ifpath=$1

    rm -rf "$ifpath" || return 1
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
