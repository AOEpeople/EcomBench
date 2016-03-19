#!/usr/bin/env bash

###INCLUDE:../../_base.sh

# create database
mysql -uroot -e 'create database b2b_dev;' || error_exit "Error creating database"

# install node.js
curl -sL https://deb.nodesource.com/setup_5.x | sudo -E bash - || error_exit "Error fetching node.js"
apt-get install -y nodejs || error_exit "Error installing node.js"

# Get ORO Commerce code
git clone https://github.com/orocommerce/orocommerce-application.git /var/www/orocommerce-application || error_exit "Error cloning oro commerce code"
sed -i.bak 's/git@github.com:/https:\/\/github.com\//g' /var/www/orocommerce-application/.gitmodules || error_exit "Error updating .gitmodules"
cd /var/www/orocommerce-application || error_exit "Error switching to app dir"
git submodule update --init --recursive || error_exit "Error fetching submodules"

# Write configuration
cat > app/config/parameters.yml <<'EOL'
parameters:
    database_driver: pdo_mysql
    database_host: 127.0.0.1
    database_port: null
    database_name: b2b_dev
    database_user: root
    database_password: null
    mailer_transport: mail
    mailer_host: 127.0.0.1
    mailer_port: null
    mailer_encryption: null
    mailer_user: null
    mailer_password: null
    websocket_bind_address: 0.0.0.0
    websocket_bind_port: 8080
    websocket_frontend_host: '*'
    websocket_frontend_port: 8080
    websocket_backend_host: '*'
    websocket_backend_port: 8080
    web_backend_prefix: /admin
    session_handler: session.handler.native_file
    locale: en
    secret: ThisTokenIsNotSoSecretChangeIt
    installed: ~
    assets_version: ~
    assets_version_strategy: time_hash
EOL

# Get dependencies
composer install --prefer-dist --no-dev || error_exit "Error running composer"

# Install
php app/console oro:install \
    --env=prod \
    --application-url="http://$(ec2metadata --public-hostname)/" \
    --organization-name="TEST" \
    --user-name="test" \
    --user-email="test@example.com" \
    --user-firstname="John" \
    --user-lastname="Doe" \
    --user-password="admin123" \
    --sample-data="y" \
    --no-interaction  || error_exit "Error running oro:install"

# Fix permissions
chmod -R ug+rw /var/www/ || error_exit "Error changing file permissions"
chown -R www-data:www-data /var/www/ || error_exit "Error changing file ownership"

ln -s /var/www/orocommerce-application/web /var/www/html || error_exit "Error linking web root"