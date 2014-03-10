#!/bin/bash
#
# Installs several persistent Python automation scripts.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 3 December 2013.
#

set -e -ex

# Prepare system for install.
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install python git

# Download all daemons from Git.
rm -rf /automation
git clone https://github.com/fatlotus/lsda-automation /automation

# Set up default configuration.
cat > /automation/config.yaml <<EOF
submit_bucket_name: ml-submissions
submit_target_directory: results
amqp: amqp.lsda.cs.uchicago.edu
zookeeper:
   - zookeeper.lsda.cs.uchicago.edu
EOF

# Create an upstart configuration file for each one.
DAEMONS=$(ls /automation/*.py)

for DAEMON in $DAEMONS; do
  DAEMON_NAME=$(basename "$DAEMON" ".py")
  
  cat > "/etc/init/$DAEMON_NAME.conf" <<EOF

description "$DAEMON_NAME"
author "Jeremy Archer"

respawn
start on startup

chdir /automation

exec /usr/bin/env python /automation/$DAEMON_NAME.py

EOF
  
  restart "$DAEMON_NAME" || start "$DAEMON_NAME"
done