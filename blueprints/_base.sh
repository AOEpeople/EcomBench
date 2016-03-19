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
apt-get -y install git lamp-server^ php5-mcrypt php5-curl php5-gd php5-intl php5-xsl || error_exit "Error installing packages"
apt-get -y install mysql-server-5.6 || error_exit "Error installing packages"
php5enmod mcrypt || error_exit "Error enabling mcrypt"
a2enmod rewrite || error_exit "Error enabling mod_rewrite"

# Apache configuration
sed -i.bak 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf || error_exit "Error configuring Apache"

# PHP Configuration
sed -i "s/.*date.timezone.*/date.timezone = \"America\/Los_Angeles\"/" /etc/php5/apache2/php.ini || error_exit "Error configuring PHP (Apache)"
sed -i "s/.*date.timezone.*/date.timezone = \"America\/Los_Angeles\"/" /etc/php5/cli/php.ini || error_exit "Error configuring PHP (cli)"

service apache2 restart || error_exit "Error restarting Apache"

rm -rf /var/www/html || error_exit "Error removing current webroot"

# Install composer
export HOME=/root
export COMPOSER_HOME=${HOME}/.composer
mkdir -p "${COMPOSER_HOME}"
curl -sS https://getcomposer.org/installer | php || error_exit "Error installing composer"
mv composer.phar /usr/local/bin/composer || error_exit "Error moving composer"
