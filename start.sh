#!/bin/bash

set -eu -o pipefail

readonly json=/app/code/node_modules/.bin/json

[[ ! -f /app/data/edition.ini ]] && echo -e "# choose 'team' (default) or 'enterprise'\nedition=team" > /app/data/edition.ini

mm_edition=$(crudini --get /app/data/edition.ini "" edition | xargs)

echo "=> Mattermost edition ${mm_edition}"
mm_root="/app/code/${mm_edition}"

if [[ ! -f /app/data/config.json ]]; then
    echo "=> Generating config on first run"

    encrypt_key=$(pwgen -1sc 32)
    public_link_salt=$(pwgen -1sc 32)
    invite_salt=$(pwgen -1sc 32)

    sed -e "s,##ENCRYPT_KEY,$encrypt_key," \
        -e "s,##PUBLIC_LINK_SALT,$public_link_salt," \
        -e "s,##INVITE_SALT,$invite_salt," \
        /app/pkg/config.json.template > /app/data/config.json

    # only set these on first run, in case user wants to change it
    $json -I -f /app/data/config.json -e "this.EmailSettings.ReplyToAddress = '${CLOUDRON_MAIL_FROM}'"
else
    # ensure all fields in config.json.template are set in config.json
    echo "=> Updating config"
    node /app/pkg/json-merge.js /app/data/config.json /app/pkg/config.json.template
fi

# the AllowCorsFrom is insecure and is a temporary workaround for #7
# the android app works but the iOS app does not with the cors setting
# NOTE: we have to skip the server cert verification because of the mismatch in server name and cert name
# We cannot use the email server name because the mail addon is configured not to provide TLS for internal hosts.
# FeedbackEmail is used as MAIL FROM
echo "=> Updating config"
$json -I -f /app/data/config.json \
    -e "this.ServiceSettings.SiteURL = '${CLOUDRON_APP_ORIGIN}'" \
    -e "this.ServiceSettings.AllowCorsFrom = '*'" \
    -e "this.SqlSettings.DriverName = 'mysql'" \
    -e "this.SqlSettings.DataSource = '${CLOUDRON_MYSQL_USERNAME}:${CLOUDRON_MYSQL_PASSWORD}@tcp(${CLOUDRON_MYSQL_HOST}:${CLOUDRON_MYSQL_PORT})/${CLOUDRON_MYSQL_DATABASE}?charset=utf8mb4,utf8'" \
    -e "this.SqlSettings.DataSourceReplicas[0] = '${CLOUDRON_MYSQL_USERNAME}:${CLOUDRON_MYSQL_PASSWORD}@tcp(${CLOUDRON_MYSQL_HOST}:${CLOUDRON_MYSQL_PORT})/${CLOUDRON_MYSQL_DATABASE}?charset=utf8mb4,utf8'" \
    -e "this.LogSettings.EnableConsole = true" \
    -e "this.LogSettings.EnableFile = true" \
    -e "this.LogSettings.FileLocation = '/run/mattermost/'" \
    -e "this.EmailSettings.EnableSMTPAuth = true" \
    -e "this.EmailSettings.ConnectionSecurity = 'TLS'" \
    -e "this.EmailSettings.SMTPUsername = '${CLOUDRON_MAIL_SMTP_USERNAME}'" \
    -e "this.EmailSettings.SMTPPassword = '${CLOUDRON_MAIL_SMTP_PASSWORD}'" \
    -e "this.EmailSettings.SMTPServer = '${CLOUDRON_MAIL_SMTP_SERVER}'" \
    -e "this.EmailSettings.SMTPPort = '${CLOUDRON_MAIL_SMTPS_PORT}'" \
    -e "this.EmailSettings.SkipServerCertificateVerification = true" \
    -e "this.EmailSettings.FeedbackEmail = '${CLOUDRON_MAIL_FROM}'" \
    -e "this.EmailSettings.FeedbackName = \"${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-Mattermost}\"" 

mkdir -p /run/mattermost /app/data/plugins /app/data/client/plugins /app/data/mmctl /app/data/templates/backup
[[ ! -f /app/data/templates/README ]] && cp /app/pkg/templates.README /app/data/templates/README
new_version=$(${mm_root}/bin/mattermost version | grep ^Version: | cut -d' ' -f 2)
[[ -f /app/data/templates/VERSION ]] && old_version=$(cat /app/data/templates/VERSION) || old_version=""

if [[ -z "${old_version}" ]]; then
    echo "=> Copying template files on first init"
    cp -rf "${mm_root}/templates.original/"* /app/data/templates/
elif [[ "${old_version}" != "${new_version}" ]]; then
    # create a backup of the file if it exists and differs
    echo "=> Updating template files"
    for file in `find ${mm_root}/templates.original/*.html -maxdepth 0 -type f -printf "%f\n"`; do
        if [[ ! -f "/app/data/templates/$file" ]]; then
            cp "${mm_root}/templates.original/$file" "/app/data/templates/$file"
        elif ! cmp --silent "/app/data/templates/$file" "${mm_root}/templates.original/$file"; then
            echo -e "\t\t $file is different from upstream"
            cp "/app/data/templates/$file" "/app/data/templates/backup/$file"
            cp "${mm_root}/templates.original/$file" "/app/data/templates/$file"
        fi
    done
else
    echo "=> Template files are up-to-date"
fi

echo "${new_version}" > /app/data/templates/VERSION

echo "=> Changing ownership"
chown -R cloudron:cloudron /app/data /run/mattermost

echo "=> Start mattermost $mm_edition"
cd "${mm_root}"
exec /usr/local/bin/gosu cloudron:cloudron ./bin/mattermost server --config=/app/data/config.json
