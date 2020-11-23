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



# Check if running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Ask value for mysql root password
read -p 'db_root_password [secretpasswd]: ' db_root_password
echo

# Update system
apt-get update -y  \
&& apt-get upgrade -y


# restart services
restart () {
    service=$1
    sudo systemctl restart $service
    status "$?"
}

# Apache and php deppendencies installation
apache_php () {
    sudo apt-get install -y apache2 php libapache2-mod-php \
    && sudo apt-get install -y graphviz aspell ghostscript \
    clamav php7.4-pspell php7.4-curl php7.4-gd php7.4-intl \
    php7.4-mysql php7.4-xml php7.4-xmlrpc php7.4-ldap \
    php7.4-zip php7.4-soap php7.4-mbstring \
    && sudo apt install -y git
}


# mysql installation and password setup
mysql_installation () {
    export DEBIAN_FRONTEND="noninteractive"
    debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_root_password"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_root_password"
    apt-get install mysql-server -y
}


# moodle download and installation
moodle () {
    cd /opt \
    && sudo git clone git://git.moodle.org/moodle.git \
    && cd moodle \
    && sudo git branch -a \
    && sudo git branch --track MOODLE_39_STABLE origin/MOODLE_39_STABLE \
    && sudo git checkout MOODLE_39_STABLE \
    && sudo cp -R /opt/moodle /var/www/html/ \
    && sudo mkdir /var/moodledata \
    && sudo chown -R www-data /var/moodledata \
    && sudo chmod -R 777 /var/moodledata \
    && sudo chmod -R 0775 /var/www/html/moodle
}


# updating default storage engine type to innodb and backup the config file.
mysql_config () {
    config_file=/etc/mysql/mysql.conf.d/mysqld.cnf
    sudo sed -i.bakup_`date +%F`-`date +%T` '/\[mysqld\]/a default_storage_engine = innodb\ninnodb_file_per_table = 1' $config_file
    restart mysql
}



# moodle db configuration and run mysql quries
moodle_db () {
    pass=$1
    mysql -u root -p$pass -e\
    "CREATE DATABASE $moodle_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \
    create user $moodle_db_user@'localhost' IDENTIFIED BY \"$moodle_db_pass\"; \
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON $moodle_db.* TO $moodle_db_user@'localhost';"
}


# install phpmyadmin
phpmyadmin () {
    sudo apt install -y  phpmyadmin php-mbstring php-zip php-gd php-json php-curl \
    && sudo phpenmod mbstring
}



url() {
    pub_ip=`curl ifconfig.me`
    echo 
    echo "http://$pub_ip/moodle"
    echo
    echo "http://$pub_ip/phpmyadmin"
}



########################
apache_php
mysql_installation
moodle
mysql_config
moodle_db $db_root_password
phpmyadmin
url

