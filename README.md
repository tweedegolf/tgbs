# TGBS

Tweede golf backup service

This image allows you to backup data in a docker/kubernetes environment to a
restic repository. This image is best suited to be run at scheduled times (e.g.
as a cron job).

The most basic operation of this image would be to mount some image/disk into
the container and create a backup from that mount. You can also mount S3 or
GCS object storage buckets to backup their files. Note that this is not
recommended for very large buckets.

This image also has an option to connect to a PostgreSQL database and create a
backup file/directory, and upload that result to a restic repository.

Most of these modes of operation are controlled by environment variables.

## Backup settings
The listing below contains a short overview of the environment variables
supported by restic and which ones are required when backing up to a repository
on Backblaze B2 storage. For details on the environment variables restic
supports, see [their documentation](https://restic.readthedocs.io/en/stable/040_backup.html#environment-variables).

### RESTIC_REPOSITORY
The repository url for the backup.

### RESTIC_PASSWORD
The password to access the repository. In a kubernetes environment this should
be made available via a secret and not directly in the kubernetes config.

### B2_ACCOUNT_ID
The account id of the account that has write access to the backblaze repository.

### B2_ACCOUNT_KEY
The secret account key of the account that has write access to the backblaze
repository.

### TGBS_BACKUP_LOCK
If this is set to `1`, the `--no-lock` flag will not be set.

### TGBS_BACKUP_TAGS
If this is set, then the backup is tagged with the value of this environment
variable. Different tags can be comma-separated. If the variable is not set,
then the backup is not tagged.

### TGBS_BACKUP_PATH
If this is specified, create a backup of the given path (either a directory or
file).

## PostgreSQL database backup
To create a PostgreSQL database backup, set the `TGBS_PSQL_BACKUP` to `1`.
To configure the database connection, use the environment variables available
to postgresql clients: https://www.postgresql.org/docs/current/libpq-envars.html

Generally you will want to set these environment variables for a simple database
backup:

    TGBS_PSQL_BACKUP=1
    PGHOST=somehost
    PGDATABASE=mydatabase
    PGUSER=myuser
    PGPASSWORD=password

Here is a full list of environment variable this image listens for:

### TGBS_PSQL_BACKUP
Set this variable to `1` to enable backups of PostgreSQL.

### TGBS_PSQL_BACKUP_TAGS
If this is set, this overrides the tags for the PostgreSQL specific part of the
backup. This variable works the same as the `TGBS_BACKUP_TAGS` variable.

### TGBS_PSQL_BACKUP_JOBS
Set the number of jobs to backup. By default this will be the number of cores
available to the backup container.

### TGBS_PSQL_BACKUP_OWNER
Set this variable to `1` to backup owner information. This is not done by
default.

### TGBS_PSQL_BACKUP_PRIVILEGES
Set this variable to `1` to backup privilege information (grants). This is not
done by default.

### TGBS_PSQL_BACKUP_FORMAT
Set this variable to `c` to change the backup format to the custom format, which
will result in a single file instead of a directory. In most cases the
directory format is more suited for backup using restic.

### TGBS_PSQL_BACKUP_COMPRESS
Set the compression level to a number between `0` (no compression) and
`9` (maximum compression).

### PGURL
Instead of specifying the `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER` and
`PGPASSWORD` environment variables individually, you can also specify the
`PGURL` variable as an (non-standard) alternative.
