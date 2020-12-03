#!/bin/bash

#########################################
# Bash script to install and setup moodle

## MySql Parameters
MYSQL_ROOT_PASSWORD="Password@123"

## PhpMyAdmin Parameters
PHP_MY_ADMIN_PASSWORD="Admin@123"

## Moodle Parameters
MOODLE_DATABASE_NAME="moodle"
MOODLE_DATABASE_USER="moodleuser"
MOODLE_DATABASE_PASSWORD="MoodlePass@123"
MOODLE_WEBSITE_NAME="Example"
MOODLE_WEBSITE_SHORT_NAME="example"
MOODLE_WEBSITE_SUMMARY="example website"
MOODLE_WEBSITE_ADMIN_USERNAME="admin"
MOODLE_WEBSITE_ADMIN_PASSWORD="Admin@123"
MOODLE_WEBSITE_ADMIN_EMAIL="admin@email.com"

## LetsEncrypt Parameters
DOMAIN="letstest.vali.life"
REGISTERED_DOMAIN_EMAIL="nagulvali555@gmail.com"


# Check if running as root
userCheck () {
    if [ "$(id -u)" != "0" ]; then
      echo "This script must be run as root" 1>&2
      echo "run sudo $0" 1>&2
      exit 1
    fi
}

# Parameter check
parameterCheck () {
    for i in MYSQL_ROOT_PASSWORD PHP_MY_ADMIN_PASSWORD MOODLE_DATABASE_NAME \
    MOODLE_DATABASE_USER MOODLE_DATABASE_PASSWORD MOODLE_WEBSITE_NAME MOODLE_WEBSITE_SHORT_NAME \
    MOODLE_WEBSITE_SUMMARY MOODLE_WEBSITE_ADMIN_USERNAME MOODLE_WEBSITE_ADMIN_PASSWORD MOODLE_WEBSITE_ADMIN_EMAIL \
    DOMAIN REGISTERED_DOMAIN_EMAIL
    do
        if [ -z "${!i}" ]
        then
            read -p "$i: " $i
        fi
    done
}

# restart services
restartService () {
    service=$1
    sudo systemctl restart $service
}

# Check the failure of the command
failCheck () {
    exitStatus=$1
    Message=$2
    if [ $exitStatus != 0 ]
    then
        echo -e "${Message}"
        exit $exitStatus
    fi
}

# Update and Upgrade packages
updates () {
    echo "updating packages"
    apt-get update -y > /dev/null \
    && apt-get upgrade -y > /dev/null
    failCheck $? "\e[7mFailed to update packages\e[0"

}

# Install Basic packages
basicPackages () {
    apt install -y net-tools mc git
    failCheck $? "\e[7mFailed to install basic packages\e[0"
}

# Install Apache
installApache () {
    sudo apt-get install -y apache2 
    failCheck $? "\e[7mFailed to install apache2\e[0"
}

# Install php and php modules
installPhpAddons () {
    sudo apt-get install -y php libapache2-mod-php graphviz aspell ghostscript \
    clamav php7.4-pspell php7.4-curl php7.4-gd php7.4-intl \
    php7.4-mysql php7.4-xml php7.4-xmlrpc php7.4-ldap \
    php7.4-zip php7.4-soap php7.4-mbstring
    failCheck $? "\e[7mFailed to install phpAddons\e[0"
}

# mysql installation and password setup
installMysql () {
    export DEBIAN_FRONTEND="noninteractive"
    echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    apt-get install mysql-server -y
    failCheck $? "\e[7mFailed to install Mysql-server\e[0"
}

# updating mysql default storage engine type to innodb and backup the config file.
configureMysql () {
    config_file=/etc/mysql/mysql.conf.d/mysqld.cnf
    sudo sed -i.bakup_`date +%F`-`date +%T` '/\[mysqld\]/a default_storage_engine = innodb\ninnodb_file_per_table = 1' $config_file
    restartService mysql
    failCheck $? "\e[7mFailed to configure Mysql\e[0"
}

# moodle download and installation
gitCloneMoodleSources () {
    cd /opt \
    && sudo git clone git://git.moodle.org/moodle.git \
    && cd moodle \
    && stable_release=$(git tag | grep "v[0-9]\+\.[0-9]\+\.[0-0]\+$" | sort -V | tail -1) \
    && sudo git checkout -b $stable_release $stable_release
    failCheck $? "\e[7mFailed to clone moodle package from source\e[0"
}

configureApacheWebContent() {
    sudo cp -R /opt/moodle /var/www/html/ \
    && sudo mkdir /var/moodledata \
    && sudo chown -R www-data /var/moodledata \
    && sudo chown -R www-data:www-data /var/www/html/moodle \
    && sudo chmod -R 777 /var/moodledata \
    && sudo chmod -R 0755 /var/www/html/moodle
    failCheck $? "\e[7mFailed to configure moodle apache content\e[0"
}

# Creating moodle Database
createDbMoodle () {
    mysql -u root -p$MYSQL_ROOT_PASSWORD -e\
    "CREATE DATABASE $MOODLE_DATABASE_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \
    create user $MOODLE_DATABASE_USER@'localhost' IDENTIFIED BY \"$MOODLE_DATABASE_PASSWORD\"; \
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON $MOODLE_DATABASE_NAME.* TO $MOODLE_DATABASE_USER@'localhost';"
    failCheck $? "\e[7mFailed to create moodle Database\e[0"
}

# install moodle from cli
installMoodle () {
    sudo -u www-data php /var/www/html/moodle/admin/cli/install.php --wwwroot="https://$DOMAIN" \
    --dataroot='/var/moodledata' --dbname="$MOODLE_DATABASE_NAME" --dbuser="$MOODLE_DATABASE_USER" --dbpass="$MOODLE_DATABASE_PASSWORD" \
    --fullname="$MOODLE_WEBSITE_NAME" --shortname="$MOODLE_WEBSITE_SHORT_NAME" --summary="$MOODLE_WEBSITE_SUMMARY" \
    --adminuser="$MOODLE_WEBSITE_ADMIN_USERNAME" --adminpass="$MOODLE_WEBSITE_ADMIN_PASSWORD" --adminemail="$MOODLE_WEBSITE_ADMIN_EMAIL" \
    --non-interactive --agree-license
    failCheck $? "\e[7mFailed to install Moodle\e[0"
}

# install phpmyadmin
installPhpmyadmin () {
    export DEBIAN_FRONTEND=noninteractive
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $PHP_MY_ADMIN_PASSWORD" |debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $PHP_MY_ADMIN_PASSWORD" | debconf-set-selections

    apt-get install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl \
    && sudo phpenmod mbstring
    failCheck $? "\e[7mFailed to install phpmyadmin packages\e[0"
#    sudo apt-get install -y  phpmyadmin php-mbstring php-zip php-gd php-json php-curl \
#    && sudo phpenmod mbstring
}

# by default only security updates are applied
setup_autoupdates(){
  apt-get install -y unattended-upgrades

  sed -i.save 's/^[\/]*Unattended-Upgrade::Remove-Unused-Kernel-Packages .*/Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";/' /etc/apt/apt.conf.d/50unattended-upgrades
  sed -i.save 's/^[\/]*Unattended-Upgrade::Remove-New-Unused-Dependencies .*/Unattended-Upgrade::Remove-New-Unused-Dependencies "true";/' /etc/apt/apt.conf.d/50unattended-upgrades
  sed -i.save 's/^[\/]*Unattended-Upgrade::Remove-Unused-Dependencies .*/Unattended-Upgrade::Remove-Unused-Dependencies "true";/' /etc/apt/apt.conf.d/50unattended-upgrades
  sed -i.save 's/^[\/]*Unattended-Upgrade::Automatic-Reboot .*/Unattended-Upgrade::Automatic-Reboot "false";/' /etc/apt/apt.conf.d/50unattended-upgrades
  sed -i.save 's/^[\/]*Unattended-Upgrade::Automatic-Reboot-Time .*/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/' /etc/apt/apt.conf.d/50unattended-upgrades
}

# Apache vhost config
apacheVirtualhost () {

    cd /etc/apache2/sites-available
    echo "
<VirtualHost *:80>
  ServerName $DOMAIN
  #ServerAlias www.$DOMAIN
  DocumentRoot /var/www/html/moodle

  <Directory /var/www/html/moodle>
     Options FollowSymLinks
     AllowOverride all
     Require all granted
  </Directory>

  ErrorLog \${APACHE_LOG_DIR}/error.log
  CustomLog \${APACHE_LOG_DIR}/access.log combined
  RewriteEngine on
  RewriteCond %{SERVER_NAME} =www.$DOMAIN [OR]
  RewriteCond %{SERVER_NAME} =$DOMAIN
  RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>" > moodle.conf

    echo "
<IfModule mod_ssl.c>
<VirtualHost *:443>
  #ServerName www.example.com

  ServerAdmin webmaster@localhost
  DocumentRoot /var/www/html/moodle
  #LogLevel info ssl:warn

  ErrorLog \${APACHE_LOG_DIR}/error.log
  CustomLog \${APACHE_LOG_DIR}/access.log combined

  # For most configuration files from conf-available/, which are
  # enabled or disabled at a global level, it is possible to
  # include a line for only one particular virtual host. For example the
  # following line enables the CGI configuration for this host only
  # after it has been globally disabled with "a2disconf".
  #Include conf-available/serve-cgi-bin.conf

  ServerName $DOMAIN
  SSLEngine On
  SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
  #Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>" > moodle-ssl.conf

    a2enmod rewrite
    a2enmod ssl
    a2ensite moodle.conf
    a2ensite moodle-ssl.conf
    a2dissite 000-default.conf
    restartService apache2
    failCheck $? "\e[7mFailed to configure apache vhosts\e[0"
}

# Enable ssl for phpmyadmin
phpmyadminSsl () {
#    echo "Include /etc/phpmyadmin/apache.conf" | tee -a /etc/apache2/apache2.conf
    sudo a2enmod ssl \
    && echo "\$cfg['ForceSSL'] = true;" | tee -a /etc/phpmyadmin/config.inc.php \
    && restartService apache2
    failCheck $? "\e[7mFailed to enable ssl for phpmyadmin\e[0"
}

# Configure php access from specific ips
phpmyadminConfig () {
    file="/etc/apache2/conf-available/phpmyadmin.conf"
    sudo cp $file $file.bkp
    sudo sed '/\<Directory \/usr\/share\/phpmyadmin\>/a    \
    Order Deny,Allow\n    Deny from All\n    Allow from 10.1.3.0/24\n    \
    Allow from 192.168.16.0/24\n    Allow from 10.1.4.0/24' $file
    
    cd `dirname $file`
    a2enconf `basename $file`
    restartService apache2
    failCheck $? "\e[7mFailed to configure phpmyadmin\e[0"
}

# Install LetsEncrypt certbot
letsencryptInstall () {
    echo -e "Installing LetsEncrypt Certbot"
    sudo apt-get install -y certbot python3-certbot-apache > /dev/null
    failCheck $? "\e[7mFailed to install LetsEncrypt\e[0m"
}

## Install LetsEncrypt certs http challenge
#leCertInstall () {
#    sudo certbot --apache -d $DOMAIN -m $REGISTERED_DOMAIN_EMAIL -n --agree-tos --redirect
#}

# LetsEncrypt DNS-01 challenge
dnsValidation () {
    echo -e "\e[34m ========================================================================== \e[0m"
    echo -e "\e[34m == LetsEncrypt DNS challenge please add acme TXT record to DNS manually == \e[0m"
    echo -e "\e[34m ========================================================================== \e[0m"
    echo 
    sudo certbot certonly --manual -d $DOMAIN -m $REGISTERED_DOMAIN_EMAIL --agree-tos \
    --no-bootstrap --manual-public-ip-logging-ok --preferred-challenges dns-01 \
    --server https://acme-v02.api.letsencrypt.org/directory

    failCheck $? "\e[31mCertBot DNS Challenge failed\e[0m"
}

# check url accessable or not
selfTest () {
    x=$(curl -sL -w "%{http_code}\\n" "https://$DOMAIN" -o /dev/null)
    if [ $x == 200 ]
    then
        echo "Moodle Installation completed successfully"
        echo "URL: https://$DOMAIN"
    else
        echo "Url Health check failed, Status code: $x"
    fi
}


########################
userCheck
parameterCheck
updates
letsencryptInstall
dnsValidation
basicPackages
installApache
installPhpAddons
installMysql
configureMysql
gitCloneMoodleSources
configureApacheWebContent
createDbMoodle
installMoodle
installPhpmyadmin
setup_autoupdates
apacheVirtualhost
phpmyadminSsl
phpmyadminConfig
restartService mysql
restartService apache2
selfTest
