#!/bin/bash
#
# Installs an Apache server with the default configuration settings.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 3 December 2013.
#

set -e -x

# Prepare system for install.
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 \
  pwauth libapache2-mod-authnz-external libpam-ldap python-pip \
  libapache2-mod-wsgi git-core nodejs pandoc nginx-extras

# Configure Apache2.
cat > /etc/apache2/ports.conf <<EOF
Listen 0.0.0.0:8081
EOF

cat > /etc/apache2/sites-available/000-default.conf <<EOF
LDAPTrustedGlobalCert CA_BASE64 /etc/ssl/certs/ca-certificates.crt
User git

<VirtualHost *:8081>
  WSGIDaemonProcess myapplication
  WSGIScriptAlias / /control-panel/app.wsgi
  
  ScriptAlias /cgi-bin /var/www
  
  <Location /cgi-bin>
    Options ExecCGI
    AddHandler cgi-script .cgi
    Allow from all
  </Location>
  
  Alias /gitlist /opt/gitlist
  
  <Directory /opt/gitlist>
    Require all granted
  </Directory>
  
  <Location /gitlist>
    Require all granted
    Options +FollowSymLinks +SymLinksIfOwnerMatch
    
    RewriteEngine On
    RewriteBase /gitlist
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [QSA,L]
  </Location>
</VirtualHost>
EOF

cat > /etc/nginx/sites-enabled/default <<EOF
server {
  listen 80;
  rewrite (.*) https://$http_host$1 permanent;
}

server {
  listen 443 ssl;
  server_name lsda.cs.uchicago.edu;

  ssl_certificate /etc/apache2/ssl/apache.crt;
  ssl_certificate_key /etc/apache2/ssl/apache.key;

  location / {
    auth_pam "CNetID";
    auth_pam_service_name "nginx";

    proxy_pass http://127.0.0.1:8082;
    proxy_set_header REMOTE_USER \$remote_user;
  }

  location /gitlist {
    auth_pam "CNetID";
    auth_pam_service_name "nginx";

    proxy_pass http://127.0.0.1:8081;
    proxy_set_header REMOTE_USER \$remote_user;
  }

  location /cgi-bin {
    auth_pam "CNetID";
    auth_pam_service_name "nginx";

    proxy_pass http://127.0.0.1:8081;
    proxy_set_header REMOTE_USER \$remote_user;
  }
}
EOF

cat > /etc/pam.d/nginx <<EOF
auth required pam_listfile.so onerr=fail item=user sense=allow file=/etc/cnetids.txt
auth required pam_ldap.so
account required pam_ldap.so
EOF

cat > /etc/apache2/envvars <<EOF
# envvars - default environment variables for apache2ctl

# this won't be correct after changing uid
unset HOME

# for supporting multiple apache2 instances
if [ "${APACHE_CONFDIR##/etc/apache2-}" != "${APACHE_CONFDIR}" ] ; then
	SUFFIX="-${APACHE_CONFDIR##/etc/apache2-}"
else
	SUFFIX=
fi

# Since there is no sane way to get the parsed apache2 config in scripts, some
# settings are defined via environment variables and then used in apache2ctl,
# /etc/init.d/apache2, /etc/logrotate.d/apache2, etc.
export APACHE_RUN_USER=git
export APACHE_RUN_GROUP=git
# temporary state file location. This might be changed to /run in Wheezy+1
export APACHE_PID_FILE=/var/run/apache2/apache2$SUFFIX.pid
export APACHE_RUN_DIR=/var/run/apache2$SUFFIX
export APACHE_LOCK_DIR=/var/lock/apache2$SUFFIX
# Only /var/log/apache2 is handled by /etc/logrotate.d/apache2.
export APACHE_LOG_DIR=/var/log/apache2$SUFFIX

## The locale used by some modules like mod_dav
export LANG=C
## Uncomment the following line to use the system default locale instead:
#. /etc/default/locale

export LANG

## The command to get the status for 'apache2ctl status'.
## Some packages providing 'www-browser' need '--dump' instead of '-dump'.
#export APACHE_LYNX='www-browser -dump'

## If you need a higher file descriptor limit, uncomment and adjust the
## following line (default is 8192):
#APACHE_ULIMIT_MAX_FILES='ulimit -n 65536'

## If you would like to pass arguments to the web server, add them below
## to the APACHE_ARGUMENTS environment.
#export APACHE_ARGUMENTS=''

## Enable the debug mode for maintainer scripts.
## This will produce a verbose output on package installations of web server modules and web application
## installations which interact with Apache
#export APACHE2_MAINTSCRIPT_DEBUG=1
EOF

# Configure LDAP.
cat > /etc/ldap/ldap.conf <<EOF
URI ldaps://ldap.uchicago.edu
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
BASE ou=people,dc=uchicago,dc=edu
EOF

# Enable WSGI dameon.
cat > /etc/init/wsgi.conf <<EOF
start on startup
respawn

setuid git

chdir /control-panel
exec /usr/bin/env python /control-panel/daemon.py
EOF

# Configure self-signed SSL certificates
a2enmod authnz_ldap
a2enmod ssl
a2enmod rewrite

mkdir -p /var/www

cd /var/www
wget https://raw.github.com/fatlotus/lsda-installation/master/generate-ssh-key.cgi
chmod +x /var/www/generate-ssh-key.cgi

# Configure the LSDA control panel.
rm -rf /control-panel
git clone https://github.com/fatlotus/lsda-control-panel.git /control-panel
pip install -r /control-panel/requirements.txt

/etc/init.d/apache2 restart || /etc/init.d/apache2 start
/etc/init.d/nginx restart || /etc/init.d/nginx start
restart wsgi || start wsgi