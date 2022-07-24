FROM postgres
ENV POSTGRES_PASSWORD postgres
ENV POSTGRES_DB postgres_source
ENV POSTGRES_HOST_AUTH_METHOD trust
COPY postgres_source.sql /docker-entrypoint-initdb.d/
