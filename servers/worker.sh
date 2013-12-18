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
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y git python python-distribute \
  python-pip build-essential python-dev

rm -rf /worker || true
mkdir -p /worker
cd /worker
git clone https://github.com/fatlotus/lsda-management.git .
pip install -r /worker/requirements.txt
chown -R lsda:lsda .

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