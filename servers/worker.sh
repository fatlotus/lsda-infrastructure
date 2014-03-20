#!/bin/bash
#
# Installs ZooKeeper on this server.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 9 December 2013.
#

set -e -x

# Prepare system for install.
useradd -m -r lsda || true
useradd -m -r sandbox || true
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y git python python-distribute \
  python-pip build-essential python-dev python-numpy python-scipy \
  python-matplotlib python-pandas python-sympy libfftw3-dev python-matplotlib

# Create worker environment.
rm -rf /worker || true
mkdir -p /worker
cd /worker
git clone https://github.com/fatlotus/lsda-management.git .
git clone https://github.com/fatlotus/lsda-data-access-layer.git dal

# Allow lsda to jump into the sandbox.
cat > /etc/sudoers.d/lsda <<EOF
lsda ALL=(root) NOPASSWD: /worker/sandbox.py *
EOF
chmod 0440 /etc/sudoers.d/lsda

pip install -r /worker/requirements.txt
pip install pyleargist # pyleargist depends on Cython to build.
chown -R lsda:lsda .
chown lsda:lsda /mnt

# Configure security.
cat > /etc/network/if-pre-up.d/sandbox-firewall <<EOF
#!/bin/bash
iptables -F
EOF
chmod +x /etc/network/if-pre-up.d/sandbox-firewall
/etc/network/if-pre-up.d/sandbox-firewall

# Configure the data access layer.
cat > /worker/dalconfig.json <<EOF
{
   "tinyimages": {
      "meta-bucket": "ml-tinyimages-metadata",
      "bucket": "ml-tinyimages"
   },
   "cache": {
      "path": "./tmp",
      "size": "unused"
   },
   "system": {
     "local": false
   }
}
EOF

# Configure daemons
cat > /etc/init/lsda.conf <<EOF
description "Runs an Python LSDA Worker Process"
author "Jeremy Archer <jarcher@uchicago.edu>"

respawn

start on startup

setuid lsda
setgid lsda

script
  python /worker/management.py \\
    --amqp=amqp.lsda.cs.uchicago.edu \\
    --zookeeper=zookeeper.lsda.cs.uchicago.edu
end script
EOF

restart lsda || start lsda