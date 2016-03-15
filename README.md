# postgres_xtm_docker

To start a container run following commands inside :

```bash
> git clone https://github.com/kelvich/postgres_xtm_docker.git
> cd postgres_xtm_docker
> docker-compose build
> docker-compose up
```

That will start three containers with postgres: one for master, and two for shard connected by postgres_fdw. 

## Testing

In xtmbemch folder we have simple test for distributed transaction (requires libpqxx). This test fill database with users across two shard and then starts to concurrently transfers money between users in dufferent shards. Also test simultaneously runs reader thread that counts all money in system.

We can ran it over our installation with postgres_fdw.

```bash
> cd xtmbench
> make
> ./xtmbench -c 'host=192.168.99.100 user=xtm' -n 300
10000 accounts inserted
Total=-1
Total=0
Total=1
Total=0
Total=1
Total=0
Total=1
Total=0
...
```

Total amount of money is fluctuating because reading transaction can access state between commits over two shards.

Now let's uncomment "TSDTM: 'yes'" in environment section in docker-compose.yml and restart caontainers:

```bash
> docker-compose down && docker-compose build && docker-compose up
> cd xtmbench
> ./dtmbench -c 'host=192.168.99.100 user=xtm' -n 300
{"tps":121.694407, "transactions":3300, "selects":55, "updates":6000,
"aborts":7, "abort_percent": 0, "readers":1, "writers":10, "update_percent":100,
"accounts":10000, "iterations":300 ,"shards":2}
```

Now Total value is not changing over time.
