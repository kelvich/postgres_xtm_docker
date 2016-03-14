CREATE EXTENSION postgres_fdw;
CREATE TABLE t(u integer primary key, v integer);

CREATE SERVER shard1 FOREIGN DATA WRAPPER postgres_fdw options(dbname 'xtm', host 'shard1', port '5432');
CREATE FOREIGN TABLE t_fdw1() inherits (t) server shard1 options(table_name 't');
CREATE USER MAPPING for xtm SERVER shard1 options (user 'xtm');

CREATE SERVER shard2 FOREIGN DATA WRAPPER postgres_fdw options(dbname 'xtm', host 'shard2', port '5432');
CREATE FOREIGN TABLE t_fdw2() inherits (t) server shard2 options(table_name 't');
CREATE USER MAPPING for xtm SERVER shard2 options (user 'xtm');

insert into t_fdw1 (select generate_series(0, 100), 0);
insert into t_fdw2 (select generate_series(100, 200), 0);
