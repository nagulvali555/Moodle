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
DOMAIN="testing.vali.life"
REGISTERED_DOMAIN_EMAIL="nagulvali555@gmail.com"
 

# Parameter check
for i in MYSQL_ROOT_PASSWORD PHP_MY_ADMIN_PASSWORD MOODLE_DATABASE_NAME \
MOODLE_DATABASE_USER MOODLE_DATABSE_PASSWORD MOODLE_WEBSITE_NAME MOODLE_WEBSITE_SHORT_NAME \
MOODLER_WEBSITE_SUMMARY MOODLE_WEBSITE_ADMIN_USERNAME MOODLE_WEBSITE_ADMIN_PASSWORD MOODLE_WEBSITE_ADMIN_EMAIL
do
    if [ -z "${!i}" ]
    then
        read -p "$i: " $i
    fi
done


# Check if running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  echo "run sudo $0" 1>&2
  exit 1
fi

# Update and Upgrade packages
apt-get update -y  \
&& apt-get upgrade -y


# restart services
restartService () {
    service=$1
    sudo systemctl restart $service
}

# Apache and php deppendencies installation
installApachePhp () {
    sudo apt-get install -y apache2 php libapache2-mod-php \
    && sudo apt-get install -y graphviz aspell ghostscript \
    clamav php7.4-pspell php7.4-curl php7.4-gd php7.4-intl \
    php7.4-mysql php7.4-xml php7.4-xmlrpc php7.4-ldap \
    php7.4-zip php7.4-soap php7.4-mbstring \
    && sudo apt install -y git
}

# mysql installation and password setup
installMysql () {
    export DEBIAN_FRONTEND="noninteractive"
    echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    apt-get install mysql-server -y
}

# updating mysql default storage engine type to innodb and backup the config file.
configureMysql () {
    config_file=/etc/mysql/mysql.conf.d/mysqld.cnf
    sudo sed -i.bakup_`date +%F`-`date +%T` '/\[mysqld\]/a default_storage_engine = innodb\ninnodb_file_per_table = 1' $config_file
    restartService mysql
}

# moodle download and installation
gitCloneMoodleSources () {
    cd /opt \
    && sudo git clone git://git.moodle.org/moodle.git \
    && cd moodle \
    && sudo git branch -a \
    && latest=$(git branch -r | grep -v origin/master | tail -n1 | awk -F "/" '{print $2}') \
    && sudo git branch --track $latest origin/$latest \
    && sudo git checkout $latest
}

configureApacheWebContent() {
    sudo cp -R /opt/moodle /var/www/html/ \
    && sudo mkdir /var/moodledata \
    && sudo chown -R www-data /var/moodledata \
    && sudo chown -R www-data:www-data /var/www/html/moodle \
    && sudo chmod -R 777 /var/moodledata \
    && sudo chmod -R 0775 /var/www/html/moodle
}

# Creating moodle Database
createDbMoodle () {
    mysql -u root -p$MYSQL_ROOT_PASSWORD -e\
    "CREATE DATABASE $MOODLE_DATABASE_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \
    create user $MOODLE_DATABASE_USER@'localhost' IDENTIFIED BY \"$MOODLE_DATABASE_PASSWORD\"; \
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON $MOODLE_DATABASE_NAME.* TO $MOODLE_DATABASE_USER@'localhost';"
}

# install moodle from cli
installMoodle () {
    sudo -u www-data php /var/www/html/moodle/admin/cli/install.php --wwwroot="https://$DOMAIN" \
    --dataroot='/var/moodledata' --dbname="$MOODLE_DATABASE_NAME" --dbuser="$MOODLE_DATABASE_USER" --dbpass="$MOODLE_DATABASE_PASSWORD" \
    --fullname="$MOODLE_WEBSITE_NAME" --shortname="$MOODLE_WEBSITE_SHORT_NAME" --summary="$MOODLE_WEBSITE_SUMMARY" \
    --adminuser="$MOODLE_WEBSITE_ADMIN_USERNAME" --adminpass="$MOODLE_WEBSITE_ADMIN_PASSWORD" --adminemail="$MOODLE_WEBSITE_ADMIN_EMAIL" \
    --non-interactive --agree-license
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


# apache config redirection will auto set by letsencrypt
apacheVirtualhost () {
    APACHE_LOG_DIR="/var/log/apache2"

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

  ErrorLog /var/log/apache2/error.log
  CustomLog /var/log/apache2/access.log combined
  #RewriteEngine on
  #RewriteCond %{SERVER_NAME} =www.$DOMAIN [OR]
  #RewriteCond %{SERVER_NAME} =$DOMAIN
  #RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>" > moodle.conf

    a2ensite moodle.conf
    a2dissite 000-default.conf
    a2enmod rewrite
    restartService apache2
}

# Install certbot and install certificates with redirect from http to https
letsencrypt () {
    sudo apt-get install -y certbot python3-certbot-apache \
    && sudo certbot --apache -d $DOMAIN -m $REGISTERED_DOMAIN_EMAIL -n --agree-tos --redirect
}

# Enable ssl for phpmyadmin
phpmyadminSsl () {
#    echo "Include /etc/phpmyadmin/apache.conf" | tee -a /etc/apache2/apache2.conf
    sudo a2enmod ssl
    echo "\$cfg['ForceSSL'] = true;" | tee -a /etc/phpmyadmin/config.inc.php
    restartService apache2
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

}

# Display information
info () {
    echo "################################################" 
    echo "#  "
    echo "# Moodle URL: https://$DOMAIN"
    echo "#  "
    echo "# phpmyadmin URL: https://$DOMAIN/phpmyadmin"
    echo "#  "
    echo "#  "
    echo "################################################"
}


########################
installApachePhp
installMysql
gitCloneMoodleSources
configureApacheWebContent
configureMysql
createDbMoodle
installMoodle
installPhpmyadmin
setup_autoupdates
apacheVirtualhost
letsencrypt
phpmyadminSsl
phpmyadminConfig
restartService mysql
restartService apache2
info