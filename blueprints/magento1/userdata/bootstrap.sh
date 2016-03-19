#!/usr/bin/env bash

###INCLUDE:../../_base.sh

# Install
wget https://files.magerun.net/n98-magerun.phar -O /usr/local/bin/n98-magerun
chmod +x /usr/local/bin/n98-magerun

cd /var/www/

n98-magerun install \
    --dbHost="localhost" \
    --dbUser="root" \
    --dbPass="" \
    --dbName="magentodb" \
    --installSampleData=yes \
    --useDefaultConfigParams=yes \
    --baseUrl="http://$(ec2metadata --public-hostname)/" \
    --magentoVersionByName="magento-mirror-1.9.2.3" \
    --installationFolder="html"

chmod -R ug+rw /var/www/
chown -R www-data:www-data /var/www/

sudo -u www-data n98-magerun sys:url:list --add-categories 1 '{path}' > categories.csv
sudo -u www-data n98-magerun sys:url:list --add-products 1 '{path}' > products.csv
sudo -u www-data n98-magerun sys:url:list --add-cmspages 1 '{path}' > cmspages.csv
