FROM cloudron/base:4.2.0@sha256:46da2fffb36353ef714f97ae8e962bd2c212ca091108d768ba473078319a47f4 AS base

FROM ghcr.io/dimitri/pgloader:latest@sha256:624bd212c571dd6149942c0f30aadb3dac33fdda3e09cc9a14a366f734717421 AS pgloader

FROM base AS final

COPY --from=pgloader /usr/local/bin/pgloader /usr/local/bin/pgloader

RUN mkdir -p /app/code/{team,enterprise} /app/pkg
WORKDIR /app/code

RUN apt-get update && apt-get install -y poppler-utils wv unrtf tidy && rm -rf /var/cache/apt /var/lib/apt/lists

ARG VERSION=9.9.0

# https://docs.mattermost.com/upgrade/upgrading-mattermost-server.html#upgrading-team-edition-to-enterprise-edition
RUN curl -L https://releases.mattermost.com/${VERSION}/mattermost-team-${VERSION}-linux-amd64.tar.gz | tar -zxf - --strip-components=1 -C /app/code/team
RUN curl -L https://releases.mattermost.com/${VERSION}/mattermost-${VERSION}-linux-amd64.tar.gz | tar -zxf - --strip-components=1 -C /app/code/enterprise
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

COPY migration.load templates.README json-merge.js config.json.template start.sh /app/pkg/

CMD [ "/app/pkg/start.sh" ]
