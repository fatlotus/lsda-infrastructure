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
  libapache2-mod-wsgi git-core

# Configure Apache2.
cat > /etc/apache2/httpd.conf <<EOF
LDAPTrustedGlobalCert CA_BASE64 /etc/ssl/certs/ca-certificates.crt
User git

Listen 0.0.0.0:1337

<VirtualHost *:443>
  SSLEngine on
  SSLCertificateFile /etc/apache2/ssl/apache.crt
  SSLCertificateKeyFile /etc/apache2/ssl/apache.key
  ServerName lsda.cs.uchicago.edu
  
  WSGIDaemonProcess myapplication
  WSGIScriptAlias / /control-panel/app.wsgi
  
  ScriptAlias /cgi-bin /var/www
  
  <Location />
    AuthBasicProvider ldap
    AuthType Basic
    AuthName "CNetID"
    AuthLDAPURL "ldaps://ldap.uchicago.edu/ou=people,dc=uchicago,dc=edu?uid?one" STARTTLS
    Require user jarcher cioc lafferty
  </Location>
  
  <Location /cgi-bin>
    Options ExecCGI
    AddHandler cgi-script .cgi
  </Location>
</VirtualHost>

<VirtualHost *:1337>
  DocumentRoot /home/git/repositories/
  
  Options ExecCGI
  AddHandler cgi-script .cgi
</VirtualHost>
EOF

# Alias /grading /var/gitlist
# 
# <Location /grading>
#   Require user jarcher lafferty
#   Options +FollowSymLinks +SymLinksIfOwnerMatch
#   
#   RewriteEngine on
#   RewriteCond %{REQUEST_FILENAME} !-f
#   RewriteRule ^(.*)$ index.php
# </Location>

# Configure LDAP.
cat > /etc/ldap.conf <<EOF
URI ldaps://ldap.uchicago.edu
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
BASE dc=uchicago,dc=edu
EOF

# Configure self-signed SSL certificates
a2enmod authnz_ldap
a2enmod ssl
a2enmod rewrite

mkdir -p /var/www

curl https://raw.github.com/fatlotus/lsda-installation/master/generate-ssh-key.cgi > /var/www/generate-ssh-key.cgi
chmod +x /var/www/generate-ssh-key.cgi

# Configure the LSDA control panel.
rm -rf /control-panel
git clone https://github.com/fatlotus/lsda-control-panel.git /control-panel
pip install -r /control-panel/requirements.txt

/etc/init.d/apache2 restart || /etc/init.d/apache2 start