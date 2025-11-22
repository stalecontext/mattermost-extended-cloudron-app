FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c AS base

FROM ghcr.io/dimitri/pgloader:latest@sha256:53b39f2da56428b96b8fb6d7f120296b904626f48740eac55b8f262de1360197 AS pgloader

FROM base AS final

COPY --from=pgloader /usr/local/bin/pgloader /usr/local/bin/pgloader

RUN mkdir -p /app/code/{team,enterprise} /app/pkg
WORKDIR /app/code

RUN apt-get update && apt-get install -y poppler-utils wv unrtf tidy && rm -rf /var/cache/apt /var/lib/apt/lists

# renovate: datasource=github-releases depName=mattermost/mattermost versioning=semver extractVersion=^v(?<version>.+)$
ARG MM_VERSION=11.1.1

# https://docs.mattermost.com/upgrade/upgrading-mattermost-server.html#upgrading-team-edition-to-enterprise-edition
# in mm 10, despite --config, we have to create the config.json symlink
RUN curl -L https://releases.mattermost.com/${MM_VERSION}/mattermost-team-${MM_VERSION}-linux-amd64.tar.gz | tar -zxf - --strip-components=1 -C /app/code/team && \
    ln -sf /app/data/config.json /app/code/team/config/config.json && \
    chown -R cloudron:cloudron /app/code/team
RUN curl -L https://releases.mattermost.com/${MM_VERSION}/mattermost-${MM_VERSION}-linux-amd64.tar.gz | tar -zxf - --strip-components=1 -C /app/code/enterprise && \
    ln -sf /app/data/config.json /app/code/enterprise/config/config.json && \
    chown -R cloudron:cloudron /app/code/enterprise
RUN npm install json

# https://github.com/mattermost/docs/blob/master/source/deploy/postgres-migration.rst
ARG GOVERSION=1.21.1
ENV GOROOT /usr/local/go-${GOVERSION}
ENV PATH $GOROOT/bin:$PATH
RUN mkdir -p /usr/local/go-${GOVERSION} && \
    curl -L https://storage.googleapis.com/golang/go${GOVERSION}.linux-amd64.tar.gz | tar zxf - -C /usr/local/go-${GOVERSION} --strip-components 1
RUN go install github.com/mattermost/morph/cmd/morph@v1
RUN go install github.com/mattermost/dbcmp/cmd/dbcmp@latest

RUN for edition in team enterprise; do \
    ln -s /app/data/plugins /app/code/${edition}/plugins && \
    ln -s /app/data/client/plugins /app/code/${edition}/client/plugins && \
    mv /app/code/${edition}/templates /app/code/${edition}/templates.original && \
    ln -s /app/data/templates /app/code/${edition}/templates; \
    done

RUN mkdir -p /home/cloudron/.config && \
    ln -s /app/data/mmctl /home/cloudron/.config/mmctl

# https://docs.mattermost.com/deploy/postgres-migration-assist-tool.html
RUN curl -L https://github.com/mattermost/migration-assist/releases/download/v0.2/migration-assist-Linux-x86_64.tar.gz | tar zxvf - -C /usr/bin migration-assist

COPY migration.load templates.README json-merge.js config.json.template start.sh /app/pkg/

CMD [ "/app/pkg/start.sh" ]
