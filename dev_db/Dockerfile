FROM mariadb

ENV MARIADB_USER hathifiles
ENV MARIADB_PASSWORD hathifiles_password
ENV MARIADB_DATABASE hathifiles
ENV MARIADB_ROOT_PASSWORD pass

COPY hathifiles.sql /docker-entrypoint-initdb.d/
