#!/bin/bash

#########################################
# Bash script to install and setup moodle

## Moodle Variables
# Moodle database name
moodle_db="moodle"
# Moodle database user
moodle_db_user="moodleuser"
# Moodle database pass
moodle_db_pass="MoodlePass@123"
# Website Name
moodle_web_name="Example"
# Web short Name
moodle_web_short_name="example"
# Web summary
moodle_web_summary="example website"
# Admin Name
moodle_admin_name="admin"
# Moodle admin pass
moodle_admin_pass="Admin@123"
# Moodle Admin Email
moodle_admin_email="admin@email.com"

## Lets Encrypt Vars
 email="nagulvali555@gmail.com"
 domain="testing.vali.life"

# Check if running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Ask value for mysql root password and php, letsencrypt
read -sp 'db_root_password [secretpasswd]: ' db_root_password
echo
read -sp 'php_myadmin_password [secretpasswd]: ' php_my_admin_pass
echo
echo

# Update and Upgrade packages
apt-get update -y  \
&& apt-get upgrade -y


# restart services
restartService () {
#FIXME: please rename to a non reserved function name e.g. restartService()
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
    echo "mysql-server mysql-server/root_password password $db_root_password" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $db_root_password" | debconf-set-selections
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
#FIXME: rename gitCloneMoodleSources()
    cd /opt \
    && sudo git clone git://git.moodle.org/moodle.git \
    && cd moodle \
    && sudo git branch -a \
    && latest=$(git branch -r | grep -v origin/master | tail -n1 | awk -F "/" '{print $2}') \
    && sudo git branch --track $latest origin/$latest \
    && sudo git checkout $latest
}

configureApacheWebContent() {
# FIXME, extract this into configureApacheWebContent()
    sudo cp -R /opt/moodle /var/www/html/ \
    && sudo mkdir /var/moodledata \
    && sudo chown -R www-data /var/moodledata \
    && sudo chown -R www-data:www-data /var/www/html/moodle \
    && sudo chmod -R 777 /var/moodledata \
    && sudo chmod -R 0775 /var/www/html/moodle
}

# Creating moodle Database
createDbMoodle () {
#FIXME: please rename to createDbMoodle()
    pass=$1
    mysql -u root -p$pass -e\
    "CREATE DATABASE $moodle_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \
    create user $moodle_db_user@'localhost' IDENTIFIED BY \"$moodle_db_pass\"; \
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON $moodle_db.* TO $moodle_db_user@'localhost';"
}

# install moodle from cli
installMoodle () {
    sudo -u www-data php /var/www/html/moodle/admin/cli/install.php --wwwroot="https://$domain" \
    --dataroot='/var/moodledata' --dbname="$moodle_db" --dbuser="$moodle_db_user" --dbpass="$moodle_db_pass" \
    --fullname="$moodle_web_name" --shortname="$moodle_web_short_name" --summary="$moodle_web_summary" \
    --adminuser="$moodle_admin_name" --adminpass="$moodle_admin_pass" --adminemail="$moodle_admin_email" \
    --non-interactive --agree-license
}

# install phpmyadmin
installPhpmyadmin () {
#FIXME: rename to installPhpmyadmin()
#    sudo apt-get install -y  phpmyadmin php-mbstring php-zip php-gd php-json php-curl \
#    && sudo phpenmod mbstring

    export DEBIAN_FRONTEND=noninteractive
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $db_root_password" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $php_my_admin_pass" |debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $php_my_admin_pass" | debconf-set-selections

    apt-get install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl \
    && sudo phpenmod mbstring
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
  ServerName $domain
#  ServerAlias www.$domain
  DocumentRoot /var/www/html/moodle

  <Directory /var/www/html/moodle>
     Options FollowSymLinks
     AllowOverride all
     Require all granted
  </Directory>

  ErrorLog /var/log/apache2/error.log
  CustomLog /var/log/apache2/access.log combined
  #RewriteEngine on
  #RewriteCond %{SERVER_NAME} =www.$domain [OR]
  #RewriteCond %{SERVER_NAME} =$domain
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
    && sudo certbot --apache -d $domain -m $email -n --agree-tos --redirect
}

# Enable ssl for phpmyadmin
phpmyadminSsl () {
    echo "Include /etc/phpmyadmin/apache.conf" | tee -a /etc/apache2/apache2.conf
    sudo a2enmod ssl
    echo "\$cfg['ForceSSL'] = true;" | tee -a /etc/phpmyadmin/config.inc.php
    restartService apache2
}

# Configure php access from specific ips
phpmyadminConfig () {
    file="/etc/apache2/conf-enabled/phpmyadmin.conf"
    sudo sed -i.bakup_`date +%F`-`date +%T` '/\<Directory \/usr\/share\/phpmyadmin\>/a    \
    Order Deny,Allow\n    Deny from All\n    Allow from 10.1.3.0/24\n    \
    Allow from 192.168.16.0/24\n    Allow from 10.1.4.0/24' $file
}

# Display information
info () {
    echo "################################################" 
    echo "# "
    echo "# Moodle URL: https://$domain"
    echo "# "
    echo "# phpmyadmin URL: https://$domain/phpmyadmin"
    echo "# "
    echo "# "
    echo "################################################"
}


########################
installApachePhp
installMysql
gitCloneMoodleSources
configureApacheWebContent
configureMysql
createDbMoodle $db_root_password
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

