#!/bin/bash
#
# Installs an Nginx server with the default configuration settings.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 3 December 2013.
#

set -e -x

# Prepare system for install.
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 \
  pwauth libapache2-mod-authnz-external libpam-ldap

# Configure Apache2.
cat > /etc/apache2/httpd.conf <<EOF
LDAPTrustedGlobalCert CA_BASE64 /etc/ssl/certs/ca-certificates.crt
LogLevel debug

<Location />
  AuthBasicProvider ldap
  AuthType Basic
  AuthName "Restricted Area"
  AuthLDAPURL "ldaps://ldap.uchicago.edu/ou=people,dc=uchicago,dc=edu?uid?one" STARTTLS
  Require valid-user
</Location>
EOF

# Configure LDAP.
cat > /etc/ldap.conf <<EOF
URI ldaps://ldap.uchicago.edu
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
BASE dc=uchicago,dc=edu
EOF

# Configure the list of students.
cat > /etc/lighttpd/allowed_users.list <<EOF
jarcher
EOF

chown nobody /etc/lighttpd/allowed_users.list
chmod 0400 /etc/lighttpd/allowed_users.list

a2enmod authnz_ldap

/etc/init.d/apache2 restart || /etc/init.d/apache2 restart