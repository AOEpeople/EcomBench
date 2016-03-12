#!/usr/bin/env bash

WAIT_CONDITION_HANDLE='{Ref:InstallationDoneHandle}'

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
        /usr/local/bin/cfn-signal --exit-code 1 --reason "DONE_EXIT" "${WAIT_CONDITION_HANDLE}";
    fi
    exit $rv
}
trap "done_exit" EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install lamp-server^ php5-mcrypt php5-curl php5-gd
php5enmod mcrypt
a2enmod rewrite

sed -i.bak 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

service apache2 restart
wget https://files.magerun.net/n98-magerun.phar -O /usr/local/bin/n98-magerun
chmod +x /usr/local/bin/n98-magerun

rm -rf /var/www/html/*

cd /var/www/html

export COMPOSER_HOME=/usr/local/bin/.composer

n98-magerun install \
    --dbHost="localhost" \
    --dbUser="root" \
    --dbPass="" \
    --dbName="magentodb" \
    --installSampleData=yes \
    --useDefaultConfigParams=yes \
    --baseUrl="http://$(ec2metadata --public-hostname)/" \
    --magentoVersionByName="magento-mirror-1.9.2.3" \
    --installationFolder="."

chmod -R ug+rw /var/www/html
chown -R www-data:www-data /var/www/html

sudo -u www-data n98-magerun sys:url:list --add-categories 1 '{path}' > categories.csv
sudo -u www-data n98-magerun sys:url:list --add-products 1 '{path}' > products.csv
sudo -u www-data n98-magerun sys:url:list --add-cmspages 1 '{path}' > cmspages.csv
