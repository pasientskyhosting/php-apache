#!/bin/bash
export USE_ZEND_ALLOC=0

# Create a log pipe so non root can write to stdout
#mkfifo -m 600 /tmp/logpipe
cat <> /tmp/logpipe 1>&2 &
chown -R www-data:www-data /tmp/logpipe

# Add new relic if key is present
# if [ ! -z "$NEW_RELIC_LICENSE_KEY" ]; then
#     export NR_INSTALL_KEY=$NEW_RELIC_LICENSE_KEY
#     newrelic-install install || exit 1
#     nrsysmond-config --set license_key=${NEW_RELIC_LICENSE_KEY} || exit 1
#     echo -e "\n[program:nrsysmond]\ncommand=nrsysmond -c /etc/newrelic/nrsysmond.cfg -l /dev/stdout -f\nautostart=true\nautorestart=true\npriority=0\nstdout_events_enabled=true\nstderr_events_enabled=true\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0" >> /etc/supervisord.conf
#
#     sed -i "s|newrelic.appname = \"PHP Application\"|newrelic.appname = \"odn1-cluster1-$PS_ENVIRONMENT-$PS_APPLICATION\"|" /etc/php/7.1/fpm/conf.d/20-newrelic.ini
#     sed -i "s|newrelic.appname = \"PHP Application\"|newrelic.appname = \"odn1-cluster1-$PS_ENVIRONMENT-$PS_APPLICATION\"|" /etc/php/7.1/cli/conf.d/20-newrelic.ini
#
#     sed -i "s|newrelic.appname = \"PHP Application\"|newrelic.appname = \"odn1-cluster1-$PS_ENVIRONMENT-$PS_APPLICATION\"|" /etc/php/7.1/fpm/conf.d/newrelic.ini
#     sed -i "s|newrelic.appname = \"PHP Application\"|newrelic.appname = \"odn1-cluster1-$PS_ENVIRONMENT-$PS_APPLICATION\"|" /etc/php/7.1/cli/conf.d/newrelic.ini
#
#     unset NEW_RELIC_LICENSE_KEY
# else
#     if [ -f /etc/php/7.1/fpm/conf.d/20-newrelic.ini ]; then
#         rm -rf /etc/php/7.1/fpm/conf.d/20-newrelic.ini
#     fi
#     if [ -f /etc/php/7.1/cli/conf.d/20-newrelic.ini ]; then
#         rm -rf /etc/php/7.1/cli/conf.d/20-newrelic.ini
#     fi
#     /etc/init.d/newrelic-daemon stop
# fi

# Set custom webroot
# if [ ! -z "$WEBROOT" ]; then
#     webroot=$WEBROOT
#     sed -i "s#root /var/www/html/web;#root ${webroot};#g" /etc/nginx/sites-available/default.conf
# else
#     webroot=/var/www/html
# fi
#
# # Set custom server name
# if [ ! -z "$SERVERNAME" ]; then
#     sed -i "s#server_name _;#server_name $SERVERNAME;#g" /etc/nginx/sites-available/default.conf
# fi


if [ -d "/adaptions" ]; then
    # make scripts executable incase they aren't
    chmod -Rf 750 /adaptions/*

    # run scripts in number order
    for i in `ls /adaptions/`; do /adaptions/$i || exit 1; done
fi

if [ -z "$PRESERVE_PARAMS" ]; then

    if [ -f /var/www/html/app/config/parameters.yml.dist ]; then
        echo "    k8s_build_id: $PS_BUILD_ID" >> /var/www/html/app/config/parameters.yml.dist
    fi

    # Composer
    if [ -f /var/www/html/composer.json ]; then
cat > /var/www/html/app/config/config_prod.yml <<EOF
imports:
    - { resource: config.yml }
monolog:
    handlers:
        main:
            type: stream
            path:  "/tmp/logpipe"
            level: error
EOF



        if [ ! -z "$PS_ENVIRONMENT" ]; then
cat > /var/www/html/app/config/parameters.yml <<EOF
parameters:
    consul_uri: $PS_CONSUL_FULL_URL
    consul_sections:
        - 'parameters/base/common.yml'
        - 'parameters/base/$PS_APPLICATION.yml'
        - 'parameters/$PS_ENVIRONMENT/common.yml'
        - 'parameters/$PS_ENVIRONMENT/$PS_APPLICATION.yml'
    env(PS_ENVIRONMENT): $PS_ENVIRONMENT
    env(PS_APPLICATION): $PS_APPLICATION
    env(PS_BUILD_ID): $PS_BUILD_ID
    env(PS_BUILD_NR): $PS_BUILD_NR
    env(PS_BASE_HOST): $PS_BASE_HOST
    env(NEW_RELIC_API_URL): $NEW_RELIC_API_URL
EOF
        fi

        cd /var/www/html
        rm -rf /var/www/html/var
        mkdir -p /var/www/html/var
        chown $APACHE_RUN_USER:$APACHE_RUN_GROUP /var/www/html/var
        chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP /var/www/html/app/config

        sudo -u $APACHE_RUN_USER /usr/bin/composer run-script build-parameters --no-interaction

        if [ -f /var/www/html/bin/console ]; then
            sudo -u $APACHE_RUN_USER /var/www/html/bin/console cache:clear --no-warmup --env=prod
            sudo -u $APACHE_RUN_USER /var/www/html/bin/console cache:warmup --env=prod
        fi

    fi

fi
