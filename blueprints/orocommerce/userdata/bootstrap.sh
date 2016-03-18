#!/usr/bin/env bash

WAIT_CONDITION_HANDLE='{Ref:InstallationDoneHandle}'
VERSION='{Ref:Version}'

echo '>>>> Installing CloudFormation tools'
mkdir aws-cfn-bootstrap-latest || { echo "Failed creating directory" ; exit 1; }
apt-get -y install python-setuptools || { echo "Failed installing python-setuptools" ; exit 1; }
curl -s https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz | tar xz -C aws-cfn-bootstrap-latest --strip-components 1 || { echo "Failed downloading aws-cfn-bootstrap-latest.tar.gz" ; exit 1; }
easy_install aws-cfn-bootstrap-latest || { echo "Failed installing aws-cfn-bootstrap-latest" ; exit 1; }

function error_exit { /usr/local/bin/cfn-signal --exit-code 1 --reason "$1" "${WAIT_CONDITION_HANDLE}"; exit 1; }

function done_exit {
    rv=$?
    if [ "$rv" == "0" ] ; then
        echo ">>> Signaling success to CloudFormation"
        /usr/local/bin/cfn-signal --exit-code $? "${WAIT_CONDITION_HANDLE}"
    else
        echo ">>> Signaling failure to CloudFormation (return value: ${rv})"
        /usr/local/bin/cfn-signal --exit-code 1 --reason "DONE_EXIT" "${WAIT_CONDITION_HANDLE}"
    fi
    exit $rv
}
trap "done_exit" EXIT

# Install LAMP server
export DEBIAN_FRONTEND=noninteractive
apt-get update || error_exit "Error while apt-get update"
apt-get -y install git lamp-server^ php5-mcrypt php5-curl php5-gd php5-intl || error_exit "Error installing packages"
php5enmod mcrypt || error_exit "Error enabling mcrypt"
a2enmod rewrite || error_exit "Error enabling mod_rewrite"

# create database
mysql -uroot -e 'create database b2b_dev;' || error_exit "Error creating database"

# install node.js
curl -sL https://deb.nodesource.com/setup_5.x | sudo -E bash - || error_exit "Error fetching node.js"
apt-get install -y nodejs || error_exit "Error installing node.js"

# Apache configuration
sed -i.bak 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf || error_exit "Error configuring Apache"

# PHP Configuration
sed -i "s/.*date.timezone.*/date.timezone = \"America\/Los_Angeles\"/" /etc/php5/apache2/php.ini || error_exit "Error configuring PHP (Apache)"
sed -i "s/.*date.timezone.*/date.timezone = \"America\/Los_Angeles\"/" /etc/php5/cli/php.ini || error_exit "Error configuring PHP (cli)"
service apache2 restart || error_exit "Error restarting Apache"

# Install composer
export COMPOSER_HOME=/usr/local/bin
curl -sS https://getcomposer.org/installer | php || error_exit "Error installing composer"
mv composer.phar /usr/local/bin/composer || error_exit "Error moving composer"

rm -rf /var/www/html || error_exit "Error removing current webroot"

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

ln -s /var/www/orocommerce-application/web /var/www/html || error_exit "Error linkin web root"