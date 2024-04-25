#!/usr/bin/env bash

set -eo pipefail

echoerr() { echo "$@" 1>&2; }

if [ ! -z "$TGBS_BACKUP_PATH" ]; then
    if [ -z "$RESTIC_REPOSITORY" ]; then
        echoerr "--- ERROR: No restic repository provided, you must provide one"
        exit 1
    fi
    echoerr "--- Creating file/directory backup"

    backup_cmd=( restic backup )

    # Add tags to the backup
    TGBS_BACKUP_TAGS_CLEAN=()
    if [ ! -z "$TGBS_BACKUP_TAGS" ]; then
        IFS=',' tag_list=("$TGBS_BACKUP_TAGS")
        for tag in ${tag_list[@]}; do
            tag="${tag#"${tag%%[![:space:]]*}"}"
            tag="${tag%"${tag##*[![:space:]]}"}"
            backup_cmd+=( --tag "'$tag'" )
            TGBS_BACKUP_TAGS_CLEAN+=( "$tag" )
        done
    fi

    TGBS_BACKUP_LOCKFILE=true
    if [ -z "$TGBS_BACKUP_LOCK" ] || [ "$TGBS_BACKUP_LOCK" == "0" ] || [ "$TGBS_BACKUP_LOCK" == "false" ]; then
        backup_cmd+=( "--no-lock" )
        TGBS_BACKUP_LOCKFILE=false
    fi

    backup_cmd+=( "$TGBS_BACKUP_PATH" )

    if [ "${#TGBS_BACKUP_TAGS_CLEAN[@]}" -gt 0 ]; then
        IFS=',' echoerr "--- Using tags for restic snapshot: ${TGBS_BACKUP_TAGS_CLEAN[*]}"
    fi
    if [ "${TGBS_BACKUP_LOCKFILE}" = false ]; then
        echoerr "--- WARNING: Not using a lockfile"
    fi
    echoerr "--- Creating restic snapshot from $TGBS_BACKUP_PATH to repository $RESTIC_REPOSITORY"

    # Run the restic command
    eval "${backup_cmd[@]}"
else
    echoerr "--- Not creating file/directory backup"
fi
