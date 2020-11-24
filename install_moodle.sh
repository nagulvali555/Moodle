#!/bin/bash

#########################################
# Bash script to install and setup moodle

# Variables

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

# SSL
# SSL certificated configured only if SSL variable set to TRUE other wise configuration will set to public ip
# If SSL set True make sure FQDN dns configured other wise letsecrypt fail to install ssl certificates
ssl="True" 

# Domain
domain="moodle.vali.life"



# Check if running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# if ssl not true then set domain to public ip
if [ $ssl != "True" ]
then
    domain="$(curl ifconfig.me)"
fi

# Ask value for mysql root password
read -sp 'db_root_password [secretpasswd]: ' db_root_password
echo

# Update system
apt-get update -y  \
&& apt-get upgrade -y


# restart services
restartService () {
#FIXME: please rename to a non reserved function name e.g. restartService()
    service=$1
    sudo systemctl restart $service
    status "$?"
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
    debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_root_password"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_root_password"
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
    && sudo git branch --track MOODLE_39_STABLE origin/MOODLE_39_STABLE \
    && sudo git checkout MOODLE_39_STABLE
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
    sudo -u www-data php /var/www/html/moodle/admin/cli/install.php --wwwroot="http://$domain" \
    --dataroot='/var/moodledata' --dbuser="$moodle_db_user" --dbpass="$moodle_db_pass" \
#    --adminname="$moodle_admin_name" --adminpass="$moodle_admin_pass" --adminemail="$moodle_admin_email" \
    --non-interactive --agree-license
}


# install phpmyadmin
installPhpmyadmin () {
#FIXME: rename to installPhpmyadmin()
    sudo apt-get install -y  phpmyadmin php-mbstring php-zip php-gd php-json php-curl \
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

  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined
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

# certbot installation and installing ssl certs on $domain
letsencrypt () {
    sudo snap install core; sudo snap refresh core \
    && sudo snap install --classic certbot \
    && sudo ln -s /snap/bin/certbot /usr/bin/certbot \
    && sudo certbot --apache -d $domain
}



# information to configure in browser
info () {
    echo "################################################" 
    echo "# Moodle URL: http://$domain"
    echo "# "
    echo "# phpmyadmin URL: http://$domain/phpmyadmin"
    echo "# "
    echo "# "
    echo "# "
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
if [ $ssl == "True"]
then
    letsencrypt
fi
info

