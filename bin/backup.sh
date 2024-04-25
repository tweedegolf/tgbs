#!/usr/bin/env bash

set -eo pipefail

/usr/local/bin/docker-psql-backup.sh
/usr/local/bin/docker-file-backup.sh
