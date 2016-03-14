# vim:set ft=dockerfile:
FROM debian

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r postgres && useradd -r -g postgres postgres

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN apt-get update \
    && apt-get install -y git \
	&& rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
	make \
	gcc \
	libreadline-dev \
	bison \
	flex \
	zlib1g-dev \ 
	&& rm -rf /var/lib/apt/lists/*

USER root
ENV CFLAGS -O0

WORKDIR /root
# RUN git clone https://github.com/postgres-x2/postgres-x2.git pg --depth 1
RUN git clone https://github.com/postgrespro/postgres_cluster.git --depth 1
WORKDIR /root/pg
RUN ./configure  --enable-cassert --enable-debug --prefix /usr/local
RUN make -j 4
RUN make install

RUN mkdir -p /var/db/postgresql && chown -R postgres /var/db/postgresql
ENV PGDATA /var/db/postgresql/
VOLUME /var/db/postgresql/

COPY docker-entrypoint.sh /

USER postgres
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
