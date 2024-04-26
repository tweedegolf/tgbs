#!/usr/bin/env bash

set -eo pipefail

MYDIR="$(dirname "$(readlink -f "$0")")"

echoerr() { echo "$@" 1>&2; }
if [ -n "$TGBS_PSQL_BACKUP" ] && [ "$TGBS_PSQL_BACKUP" != "0" ] && [ "$TGBS_PSQL_BACKUP" != "false" ]; then
    if [ -z "$RESTIC_REPOSITORY" ]; then
        echoerr "--- ERROR: No restic repository provided, you must provide one"
        exit 1
    fi

    # Convert a postgresql database url to the individual database parameters
    eval "$("$MYDIR/pgurlparams.py")"

    # Determine the list of databases to backup
    if [ -n "$TGBS_PSQL_BACKUP_ALL" ] && [ "$TGBS_PSQL_BACKUP_ALL" != "0" ] && [ "$TGBS_PSQL_BACKUP_ALL" != "false" ]; then
        databases=$(psql -t -A -c "SELECT datname FROM pg_database WHERE datallowconn = true AND datistemplate = false AND has_database_privilege(datname, 'CREATE');")
    else
        if [ -z "$PGDATABASE" ]; then
            PGDATABASE=$(psql -t -A -c 'SELECT current_database()')
        fi

        databases=("$PGDATABASE")
    fi

    # Storage for all backup filenames
    TGBS_PSQL_BACKUP_FILENAMES=()

    # Create the dump directory
    dump_dir="/tmp/psql"
    mkdir -p "$dump_dir"

    # Determine the base arguments for the pg_dump command
    base_args=()

    # Set whether to backup the owner information
    if [ -z "$TGBS_PSQL_BACKUP_OWNER" ] || [ "$TGBS_PSQL_BACKUP_OWNER" == "0" ] || [ "$TGBS_PSQL_BACKUP_OWNER" == "false" ]; then
        base_args+=( "--no-owner" )
        TGBS_PSQL_BACKUP_OWNER=false
    else
        TGBS_PSQL_BACKUP_OWNER=true
    fi

    # Set whether to backup the privilege (grants) information
    if [ -z "$TGBS_PSQL_BACKUP_PRIVILEGES" ] || [ "$TGBS_PSQL_BACKUP_PRIVILEGES" == "0" ] || [ "$TGBS_PSQL_BACKUP_PRIVILEGES" == "false" ]; then
        base_args+=( "--no-privileges" )
        TGBS_PSQL_BACKUP_PRIVILEGES=false
    else
        TGBS_PSQL_BACKUP_PRIVILEGES=true
    fi

    # Determine the compression level and the backup format
    if [ -z "$TGBS_PSQL_BACKUP_COMPRESS" ]; then
        TGBS_PSQL_BACKUP_COMPRESS=9
    fi
    if ! [[ "$TGBS_PSQL_BACKUP_COMPRESS" =~ ^[+-]?[0-9]+$ ]]; then
        echoerr "--- WARNING: Compression level must be an integer, setting to 9"
        TGBS_PSQL_BACKUP_COMPRESS=9
    fi
    if [ "$TGBS_PSQL_BACKUP_COMPRESS" -lt 0 ]; then
        echoerr "--- WARNING: Compression level must be between 0 and 9, setting to 0"
        TGBS_PSQL_BACKUP_COMPRESS=0
    fi
    if [ "$TGBS_PSQL_BACKUP_COMPRESS" -gt 9 ]; then
        echoerr "--- WARNING: Compression level must be between 0 and 9, setting to 9"
        TGBS_PSQL_BACKUP_COMPRESS=9
    fi

    # Determine the backup format
    if [ -z "$TGBS_PSQL_BACKUP_FORMAT" ]; then
        TGBS_PSQL_BACKUP_FORMAT="d"
    fi
    TGBS_PSQL_BACKUP_FORMAT=$(echo "$TGBS_PSQL_BACKUP_FORMAT" | tr '[:upper:]' '[:lower:]')
    format_matched=false
    for fmt in "c" "d" "t" "p"; do
        if [ "$fmt" == "$TGBS_PSQL_BACKUP_FORMAT" ]; then
            format_matched=true
        fi
    done
    if [ "$format_matched" == false ]; then
        echoerr "--- WARNING: Unknown format, using directory format instead"
        TGBS_PSQL_BACKUP_FORMAT="d"
    fi
    if [ "$TGBS_PSQL_BACKUP_FORMAT" == "t" ] || [ "$TGBS_PSQL_BACKUP_FORMAT" == "p" ]; then
        TGBS_PSQL_BACKUP_COMPRESS=0 # Compression not supported for tar or SQL
    fi
    base_args+=( "--format=$TGBS_PSQL_BACKUP_FORMAT" "--compress=$TGBS_PSQL_BACKUP_COMPRESS" )

    # Determine the number of jobs to run
    proc_count="$(nproc)"
    if [ "$TGBS_PSQL_BACKUP_FORMAT" != "d" ]; then
        proc_count=1
    fi
    if [ -z "$TGBS_PSQL_BACKUP_JOBS" ]; then
        TGBS_PSQL_BACKUP_JOBS="$proc_count"
    fi
    if ! [[ "$TGBS_PSQL_BACKUP_JOBS" =~ ^[+-]?[0-9]+$ ]]; then
        echoerr "--- WARNING: Number of jobs must be an integer, setting to $proc_count"
        TGBS_PSQL_BACKUP_JOBS="$proc_count"
    fi
    if [ "$TGBS_PSQL_BACKUP_JOBS" -lt 1 ]; then
        echoerr "--- WARNING: Must have at least 1 job, setting to 1"
        TGBS_PSQL_BACKUP_JOBS=1
    fi
    base_args+=( "--jobs=$TGBS_PSQL_BACKUP_JOBS" )

    # Run the backup command for each individual database
    IFS=$'\n'

    for db in $databases; do
        echoerr "--- Creating PostgreSQL backup for database $db"
        psql_cmd=( "pg_dump" )

        # Switch over the format to determine the filename
        case "$TGBS_PSQL_BACKUP_FORMAT" in
        c)
            TGBS_PSQL_BACKUP_FORMAT_NAME=custom
            TGBS_PSQL_BACKUP_FILENAME="$dump_dir/$db.dump"
            ;;
        d)
            TGBS_PSQL_BACKUP_FORMAT_NAME=directory
            TGBS_PSQL_BACKUP_FILENAME="$dump_dir/$db"
            ;;
        t)
            TGBS_PSQL_BACKUP_FORMAT_NAME=tar
            TGBS_PSQL_BACKUP_FILENAME="$dump_dir/$db.tar"
            ;;
        p)
            TGBS_PSQL_BACKUP_FORMAT_NAME=plain-text
            TGBS_PSQL_BACKUP_FILENAME="$dump_dir/$db.sql"
            ;;
        esac
        psql_cmd+=( "--file='$TGBS_PSQL_BACKUP_FILENAME'" )

        # Add the base arguments
        psql_cmd+=( "${base_args[@]}" )

        # Notify that we start creating the backup now
        echoerr "--- Creating a database backup of $db using $TGBS_PSQL_BACKUP_JOBS jobs in format $TGBS_PSQL_BACKUP_FORMAT_NAME"
        echoerr "--- Saving backup of database $db to $TGBS_PSQL_BACKUP_FILENAME"

        # Run the pg_dump command
        PGDATABASE="$db" eval "${psql_cmd[@]}"

        # Add the filename to the list of files
        TGBS_PSQL_BACKUP_FILENAMES+=( "$TGBS_PSQL_BACKUP_FILENAME" )
    done

    backup_cmd=( restic backup )

    # Add tags to the backup
    TGBS_PSQL_BACKUP_TAGS="${TGBS_PSQL_BACKUP_TAGS:-${TGBS_BACKUP_TAGS}}"
    TGBS_PSQL_BACKUP_TAGS_CLEAN=()
    if [ -n "$TGBS_PSQL_BACKUP_TAGS" ]; then
        IFS=',' tag_list=("$TGBS_PSQL_BACKUP_TAGS")
        for tag in "${tag_list[@]}"; do
            tag="${tag#"${tag%%[![:space:]]*}"}"
            tag="${tag%"${tag##*[![:space:]]}"}"
            backup_cmd+=( --tag "'$tag'" )
            TGBS_PSQL_BACKUP_TAGS_CLEAN+=( "$tag" )
        done
    fi

    # Backup all previously created psql files
    backup_cmd+=( "${TGBS_PSQL_BACKUP_FILENAMES[@]}" )

    if [ "${#TGBS_PSQL_BACKUP_TAGS_CLEAN[@]}" -gt 0 ]; then
        IFS=',' echoerr "--- Using tags for restic snapshot: ${TGBS_PSQL_BACKUP_TAGS_CLEAN[*]}"
    fi

    echoerr "--- Creating restic snapshot from PostgreSQL backup to repository $RESTIC_REPOSITORY"

    # Run the restic command
    eval "${backup_cmd[@]}"

    echoerr "--- PostgreSQL backup complete"
else
    echoerr "--- Not creating PostgreSQL backup"
fi
