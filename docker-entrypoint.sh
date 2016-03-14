#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
	mkdir -p "$PGDATA"
	chmod 700 "$PGDATA"
	chown -R postgres "$PGDATA"

	chmod g+s /run/postgresql
	chown -R postgres /run/postgresql

	# look specifically for PG_VERSION, as it is expected in the DB dir
	if [ ! -s "$PGDATA/PG_VERSION" ]; then
		gosu postgres initdb

		# check password first so we can output the warning before postgres
		# messes it up
		if [ "$POSTGRES_PASSWORD" ]; then
			pass="PASSWORD '$POSTGRES_PASSWORD'"
			authMethod=md5
		else
			# The - option suppresses leading tabs but *not* spaces. :)
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				         This will allow anyone with access to the
				         Postgres port to access your database. In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.
				         Use "-e POSTGRES_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN

			pass=
			authMethod=trust
		fi

		{ echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA/pg_hba.conf"


		############################################################################

		echo "listen_addresses='*'" >> "$PGDATA/postgresql.conf"
		echo "max_prepared_transactions = 100" >> "$PGDATA/postgresql.conf"
		echo "fsync = off" >> "$PGDATA/postgresql.conf"

		if [ "$ROLE" = 'shard' ]; then
			echo "shared_preload_libraries = 'pg_tsdtm'" >> "$PGDATA/postgresql.conf"
		fi

		if [ "$TSDTM" = 'yes' ]; then
			echo "postgres_fdw.use_tsdtm = 1" >> "$PGDATA/postgresql.conf"
		fi

		############################################################################


		# internal start of server in order to allow set-up using psql-client		
		# does not listen on TCP/IP and waits until start finishes
		gosu postgres pg_ctl -D "$PGDATA" \
			-o "-c listen_addresses=''" \
			-w start

		: ${POSTGRES_USER:=postgres}
		: ${POSTGRES_DB:=$POSTGRES_USER}
		export POSTGRES_USER POSTGRES_DB

		psql=( psql -v ON_ERROR_STOP=1 )

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			"${psql[@]}" --username postgres <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi

		if [ "$POSTGRES_USER" = 'postgres' ]; then
			op='ALTER'
		else
			op='CREATE'
		fi
		"${psql[@]}" --username postgres <<-EOSQL
			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
		EOSQL
		echo


		############################################################################

		"${psql[@]}" -U postgres "$POSTGRES_DB" <<-EOSQL
			CREATE TABLE t(u integer primary key, v integer);
		EOSQL

		if [ "$ROLE" = "shard" ]; then
			"${psql[@]}" -U postgres "$POSTGRES_DB" <<-EOSQL
				CREATE EXTENSION pg_tsdtm;
			EOSQL
		fi

		if [ "$ROLE" = "master" ]; then
			"${psql[@]}" -U postgres "$POSTGRES_DB" <<-EOSQL
				CREATE EXTENSION postgres_fdw;
				CREATE SERVER shard1 FOREIGN DATA WRAPPER postgres_fdw options(dbname 'xtm', host 'shard1', port '5432');
				CREATE FOREIGN TABLE t_fdw1() inherits (t) server shard1 options(table_name 't');
				CREATE USER MAPPING for xtm SERVER shard1 options (user 'xtm');
				CREATE SERVER shard2 FOREIGN DATA WRAPPER postgres_fdw options(dbname 'xtm', host 'shard2', port '5432');
				CREATE FOREIGN TABLE t_fdw2() inherits (t) server shard2 options(table_name 't');
				CREATE USER MAPPING for xtm SERVER shard2 options (user 'xtm');
			EOSQL
		fi

		############################################################################

		psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${psql[@]}" < "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

		echo
		echo 'PostgreSQL init process complete; ready for start up.'
		echo
	fi

	exec gosu postgres "$@"
fi

exec "$@"
