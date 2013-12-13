#!/bin/bash
#
# Installs RabbitMQ on this server.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 9 December 2013.
#

set -e -x

# Prepare system for install.
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install rabbitmq-server
