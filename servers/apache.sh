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
User git

Listen 0.0.0.0:1337

<VirtualHost *:443>
  SSLEngine on
  SSLCertificateFile /etc/apache2/ssl/apache.crt
  SSLCertificateKeyFile /etc/apache2/ssl/apache.key
  
  DocumentRoot /var/www
  
  <Location />
    AuthBasicProvider ldap
    AuthType Basic
    AuthName "CNetID"
    AuthLDAPURL "ldaps://ldap.uchicago.edu/ou=people,dc=uchicago,dc=edu?uid?one" STARTTLS
    Require user jarcher cioc lafferty borja howens
  
    Options ExecCGI
    AddHandler cgi-script .cgi
  </Location>
  
  <Location /gitlist>
    Require user jarcher lafferty
  </Location>
</VirtualHost>

<VirtualHost *:1337>
  DocumentRoot /home/git/repositories/
</VirtualHost>
EOF

# Configure LDAP.
cat > /etc/ldap.conf <<EOF
URI ldaps://ldap.uchicago.edu
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
BASE dc=uchicago,dc=edu
EOF

# Configure self-signed SSL certificates
mkdir -p /etc/apache2/ssl
chown git /etc/apache2/ssl
chmod 0500 /etc/apache2/ssl

cat > /etc/apache2/ssl/apache.crt <<EOF
-----BEGIN CERTIFICATE-----
MIIE8TCCA9mgAwIBAgIJAKbEXISQ5rsoMA0GCSqGSIb3DQEBBQUAMIGrMQswCQYD
VQQGEwJVUzERMA8GA1UECBMISWxsaW5vaXMxEDAOBgNVBAcTB0NoaWNhZ28xHjAc
BgNVBAoTFVVuaXZlcnNpdHkgb2YgQ2hpY2FnbzETMBEGA1UECxMKQ01TQyAyNTAy
NTEdMBsGA1UEAxMUbHNkYS5jcy51Y2hpY2Fnby5lZHUxIzAhBgkqhkiG9w0BCQEW
FGphcmNoZXJAdWNoaWNhZ28uZWR1MB4XDTEzMTIwNDE4MzEwMFoXDTE0MTIwNDE4
MzEwMFowgasxCzAJBgNVBAYTAlVTMREwDwYDVQQIEwhJbGxpbm9pczEQMA4GA1UE
BxMHQ2hpY2FnbzEeMBwGA1UEChMVVW5pdmVyc2l0eSBvZiBDaGljYWdvMRMwEQYD
VQQLEwpDTVNDIDI1MDI1MR0wGwYDVQQDExRsc2RhLmNzLnVjaGljYWdvLmVkdTEj
MCEGCSqGSIb3DQEJARYUamFyY2hlckB1Y2hpY2Fnby5lZHUwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQCbZpy/pODB09pfAZ5h2AOErJvcuqUe0IidsrSN
3zTKhgIB0OHLWsVdNs19ley43Kt8zCP0feqYd7lBd6qcVRRodeG3CPNtnWVYDWcn
Csam6L1yipTxuG+VIGwDxqFzKcrf5bnrQm/+sWr7RWJEZA+xxkyY7UFuERNUmaZw
VISom26ZKeQPOB0aJsVuYDsn+7Nd5/86uyanCTprRAIgxlZkMy18HmhTW0TB4HrM
guyrAWMIZXJL8SStBsyGmNX4HUdCjRHQbucUKXyqg8vcE78rykH6Osnk16zMPvXY
gbV1bXJ6oR1BhLpsLSvpMjH5ypfyBDDAf4RTLtmRLYXJtliDAgMBAAGjggEUMIIB
EDAdBgNVHQ4EFgQUWz/tjSFD02s+m5hrZup7WWZgckQwgeAGA1UdIwSB2DCB1YAU
Wz/tjSFD02s+m5hrZup7WWZgckShgbGkga4wgasxCzAJBgNVBAYTAlVTMREwDwYD
VQQIEwhJbGxpbm9pczEQMA4GA1UEBxMHQ2hpY2FnbzEeMBwGA1UEChMVVW5pdmVy
c2l0eSBvZiBDaGljYWdvMRMwEQYDVQQLEwpDTVNDIDI1MDI1MR0wGwYDVQQDExRs
c2RhLmNzLnVjaGljYWdvLmVkdTEjMCEGCSqGSIb3DQEJARYUamFyY2hlckB1Y2hp
Y2Fnby5lZHWCCQCmxFyEkOa7KDAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUA
A4IBAQAbETVb4gf+rOnSNcAwm8o6OncZM/aYDrZUd0dpe/327I7DiNTUvskYNEIM
N6x5kNG5U8wJdoZojKYQujc/gpTnTl7bjltL72xKSGfWYBNBrdCxfxexE2SifpWW
ffD+Y/ytiT+OrRBPb5X8LNxU2BHMVtDHX6uHSzxeJcn2i+jzbVblMER+LEF4Z0Kk
p/AiN1QlcTMXG6l/1RQrLSd4IXQieYV4vMGEye1cd2OOifU6x7RLwqbiS2psU614
DSP+uEGhZr4mDpuLTgibV0E9fUYMz1yogzDQHMOPsfnBDo8hy3KpvGt97hkS23dM
Z+Zh0sfgRwrqg6N+3g652U5vZRgs
-----END CERTIFICATE-----
EOF

cat > /etc/apache2/ssl/apache.key <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAm2acv6TgwdPaXwGeYdgDhKyb3LqlHtCInbK0jd80yoYCAdDh
y1rFXTbNfZXsuNyrfMwj9H3qmHe5QXeqnFUUaHXhtwjzbZ1lWA1nJwrGpui9coqU
8bhvlSBsA8ahcynK3+W560Jv/rFq+0ViRGQPscZMmO1BbhETVJmmcFSEqJtumSnk
DzgdGibFbmA7J/uzXef/Orsmpwk6a0QCIMZWZDMtfB5oU1tEweB6zILsqwFjCGVy
S/EkrQbMhpjV+B1HQo0R0G7nFCl8qoPL3BO/K8pB+jrJ5NeszD712IG1dW1yeqEd
QYS6bC0r6TIx+cqX8gQwwH+EUy7ZkS2FybZYgwIDAQABAoIBAQCA8WzAy+M+kTXR
vTsY/q80qDCPv0MBRZEGIOEWEw3vua/yp8qi/IdlJ/Lr8LnCTj/wxkZTOSOuLTFH
dC7ZlvLfFmkagc/StVYA8OYVjCh3GAkSAJFD3IChoYxeubL/Jr9SdoCFB9R75eTZ
56F5E/m9zceC4OJ4nKyIdxGWhVqptzvWRpRWoEg740R3oFnnIxt0pqsagNP509yf
T++LPFFtnjyceKS1x6TR2F6AP4F51N80NL7LbaWSWKwe/mh3eaTqpTcbUKYYm3hj
1RYaBwJiVZJRII5ZQFfEPhVC1sOve/yAC/qxIiAflcL+mCmdjkK/dp8L9l1JuHkG
m5e1aclRAoGBAMgwAbuhqAvdqIXj+CpzGHnv3BinZElVglpWiJmLcJElIKCOnwV7
V0HBjpt/ED+I44/LXIvY84FGh3ikqzo3oZUoQvsTgAQ7taYoE4JvCK/YDVKmBj6U
7JtNdhRZgnboVHlx0gJIkWo65wiBOzOUGgsyoyxi7ENb9RHI2lhKWg5ZAoGBAMa6
Cuf1s6m0KkyAXtv1j9pXFiG1SW+X0EaRGPJNNE4XEDR547E0yK/q3uKUtVfk4b7N
SwUTn/R+yILoyOeu1Cud0TSnKA8nNt+MAJ7YvGunI8y8+JNE47loH15K+N4eEpzd
7dQ76eMhbHc1/em+8YnE1pIUI0tI27xigjJdgBo7AoGAcOsbXyINbzwFvhhcOF2Z
tdZFeSaam/7+u0RKYwnTYhvmLoqkSmxLSM0MSsu+d4gYjFiyiDPFDuugqL2B1CHj
JAaE2akjMcAYc3PxpUZKSR3+TdtWdGB+og9shogC3l2ooKRCSIV0eM5m2VZD9ZEZ
q61Re00FZe1t7C02dEzkRWkCgYBNccs2QmZVyESDs7ND/RqmeDHDySZpOryMA5e5
NaUgmZRTHv1A3dUn2Vwq6NETA7uF4/NMcy1u1snFWnqQ72z34nTZFBtkbF/SFnlX
bhdfzK8C5tHocnxckNtIn+cEiKuwPjyk7QRk422lt4DQSv1ON0t3eimW+TnI3Iro
nc+CaQKBgHmOKv+iKV7upfapj1MKuaAyXh+zrLZbAnlz1REAnseAcoUTaQ/Zk0FT
O6Ml1UOUai+WEqCOfFAV8zrdv+cBWcDjqAD5m7n6xyx6OXLOvty1kHiE/CCB+Nq/
ETHhE+IDC/NJgw5B0bRkEpbi+01nGod1KvXZwZa58HIZA/Wbxws4
-----END RSA PRIVATE KEY-----
EOF

a2enmod authnz_ldap
a2enmod ssl

mkdir -p /var/www

curl https://raw.github.com/fatlotus/lsda-installation/master/generate-ssh-key.cgi > /var/www/generate-ssh-key.cgi
chmod +x /var/www/generate-ssh-key.cgi

/etc/init.d/apache2 restart || /etc/init.d/apache2 start