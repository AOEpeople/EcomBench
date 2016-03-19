#!/usr/bin/env bash

###INCLUDE:../../_base.sh

# Configure composer auth
cat > "${COMPOSER_HOME}/auth.json" <<'EOL'
{
    "http-basic": {
        "repo.magento.com": {
            "username": "{Ref:MagentoRepoUsername}",
            "password": "{Ref:MagentoRepoPassword}"
        }
    },
    "github-oauth": {
        "github.com": "{Ref:GithubToken}"
    }
}
EOL




# Install
wget https://files.magerun.net/n98-magerun2.phar -O /usr/local/bin/n98-magerun2
chmod +x /usr/local/bin/n98-magerun2

cd /var/www/

n98-magerun2 install \
    --dbHost="localhost" \
    --dbUser="root" \
    --dbPass="" \
    --dbName="magentodb" \
    --installSampleData=yes \
    --useDefaultConfigParams=yes \
    --baseUrl="http://$(ec2metadata --public-hostname)/" \
    --magentoVersionByName="magento-ce-2.0.2" \
    --installationFolder="html"

# Issue while installing Sample Data:
# [Composer\Downloader\TransportException]
# The 'https://repo.magento.com/packages.json' URL required authentication.
# You must be using the interactive console to authenticate
#
# Workaround:

cd /var/www/html
composer update
chmod +x bin/magento
bin/magento setup:upgrade
bin/magento setup:di:compile
bin/magento cache:flush

chmod -R ug+rw /var/www/
chown -R www-data:www-data /var/www/

sudo -u www-data n98-magerun2 sys:url:list --add-categories 1 '{path}' | sed -e 's/\/\//\//g' > categories.csv
sudo -u www-data n98-magerun2 sys:url:list --add-products 1 '{path}' | sed -e 's/\/\//\//g' > products.csv
sudo -u www-data n98-magerun2 sys:url:list --add-cmspages 1 '{path}' | sed -e 's/\/\//\//g' > cmspages.csv