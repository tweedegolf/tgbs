#!/usr/bin/env python3
from urllib.parse import urlparse
import os

if 'PGURL' in os.environ:
    result = urlparse(os.environ['PGURL'])
    if result.scheme == 'pg' or result.scheme == 'postgres' or result.scheme == 'pgsql' or result.scheme == 'psql' or result.scheme == 'postgresql':
        os.environ['PGHOST'] = result.hostname
        if result.username is not None:
            os.environ['PGUSER'] = result.username
        if result.password is not None:
            os.environ['PGPASSWORD'] = result.password
        if result.port is not None:
            os.environ['PGPORT'] = "{}".format(result.port)
        if len(result.path) > 1 and result.path[0] == '/':
            os.environ['PGDATABASE'] = result.path[1:]

if 'PGHOST' in os.environ:
    print("export PGHOST=\"{}\"".format(os.environ['PGHOST']))

if 'PGUSER' in os.environ:
    print("export PGUSER=\"{}\"".format(os.environ['PGUSER']))

if 'PGPASSWORD' in os.environ:
    print("export PGPASSWORD=\"{}\"".format(os.environ['PGPASSWORD']))

if 'PGPORT' in os.environ:
    print("export PGPORT=\"{}\"".format(os.environ['PGPORT']))

if 'PGDATABASE' in os.environ:
    print("export PGDATABASE=\"{}\"".format(os.environ['PGDATABASE']))

