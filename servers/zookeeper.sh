#!/bin/bash
#
# Installs ZooKeeper on this server.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 9 December 2013.
#

set -e -x

# Prepare system for install.
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install zookeeper zookeeperd

cat > /etc/zookeeper/conf/zoo.cfg <<EOF
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/var/lib/zookeeper
clientPort=2181
# server.1=zookeeper1:2888:3888
# server.2=zookeeper2:2888:3888
# server.3=zookeeper3:2888:3888
EOF

restart zookeeper