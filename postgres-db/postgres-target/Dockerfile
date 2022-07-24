FROM postgres
ENV POSTGRES_PASSWORD postgres
ENV POSTGRES_DB postgres_target
ENV POSTGRES_HOST_AUTH_METHOD trust
COPY postgres_target.sql /docker-entrypoint-initdb.d/
