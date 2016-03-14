CREATE EXTENSION postgres_fdw;

CREATE SERVER shard1 FOREIGN DATA WRAPPER postgres_fdw options(dbname 'xtm', host 'shard1', port '5432');
CREATE FOREIGN TABLE t_fdw1() inherits (t) server shard1 options(table_name 't');
CREATE USER MAPPING for xtm SERVER shard1 options (user 'xtm');

CREATE SERVER shard2 FOREIGN DATA WRAPPER postgres_fdw options(dbname 'xtm', host 'shard2', port '5432');
CREATE FOREIGN TABLE t_fdw2() inherits (t) server shard2 options(table_name 't');
CREATE USER MAPPING for xtm SERVER shard2 options (user 'xtm');
