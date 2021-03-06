FROM openjdk:8-jre-alpine

# Add studio group and user
RUN addgroup -g 9091 studio \
    && adduser -G studio -h /home/studio -D -u 9091 studio

# gosu for easy step down from root
ENV GOSU_VERSION 1.9
RUN set -x \
    && apk add --no-cache --virtual .gosu-deps \
        dpkg \
        gnupg \
        openssl \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apk del .gosu-deps

# See the build scripts and the STUDIO_VERSION file for setting this value
ARG STUDIO_VERSION

# Download, verify, and unpack Studio
RUN set -x \
    && apk add --no-cache --virtual .studio-deps \
        openssl \
    && wget "https://downloads.datastax.com/datastax-studio/datastax-studio-$STUDIO_VERSION.tar.gz" \
    && wget "https://downloads.datastax.com/datastax-studio/datastax-studio-$STUDIO_VERSION.tar.gz.md5" \
    && md5sum -c *.md5 \
    && mkdir /opt \
    && tar -xzvf "datastax-studio-$STUDIO_VERSION.tar.gz" -C /opt \
    && mv "/opt/datastax-studio-$STUDIO_VERSION" /opt/studio \
    && chown -R studio:studio /opt/studio \
    && rm "datastax-studio-$STUDIO_VERSION.tar.gz" "datastax-studio-$STUDIO_VERSION.tar.gz.md5" \
    && apk del .studio-deps

# The server launch script wants bash, so install it
RUN set -x \
    && apk add --no-cache bash

# Create directory for user data (this is the default location where connections and notebooks are saved)
RUN mkdir /opt/studio/userdata \
    && chown -R studio:studio /opt/studio/userdata

# Set some default configuration settings in the yaml
RUN sed -i 's/httpBindAddress: localhost/httpBindAddress: 0.0.0.0/' /opt/studio/conf/configuration.yaml \
    && sed -i 's_baseDirectory: null_baseDirectory: /opt/studio/userdata_' /opt/studio/conf/configuration.yaml

# Volumes for configuration files and user data
VOLUME [ "/opt/studio/conf", "/opt/studio/userdata" ]

# Entrypoint script for launching
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

# Expose the web UI port for studio
EXPOSE 9091

# Command to start the server
CMD [ "/opt/studio/bin/server.sh" ]