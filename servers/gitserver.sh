#!/usr/bin/env bash
#
# Installs a Gitolite server on a fresh Ubuntu box.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 3 December 2013.
#

set -e -x

# Prepare the system for install.
useradd -m -r git || true
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y git python

cd /home/git

su - git <<EOF

set -e -x

# Include my public key in the setup process.
cat > jeremy.pub <<NEOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCpZxfYDGv07zdwv2Qa7SLIUi74rhR6D7y41uVbo6SUn3EbJbc7rSgO+CTgQTbbTNn9eEjMxQ3Q2QRt9FdyTRT6Gn607gtqi1uKkuRkkIxDTGNmRgrbC55M8Q07u8Z1PJvOmd5MnP3Et2dQdVJ1UCawNQLuktPup7sLBafsPHiDUnjTrI61x0E2fnyXOOlr1NmLWYQ4Plp8lQhOF9Y1hx8et3k0/y/r/TaVa5VI12kJ11f0vvvaZhAqKdbEKZE1XOYVD8ZrH8qs/x1a807Ilcvvr6LJ0TnZ3aUYL80cBT3IbCNwDgqytGXMCyBh9KTnjMB4neIkUYGkiyCDfzhQPzyr spectre-secure
NEOF

# Wipe out any existing keys (since we mess with this file later)
rm -rf ~/.ssh/authorized_keys

# Fetch and Install Gitolite
git clone git://github.com/sitaramc/gitolite || true
gitolite/src/gitolite setup -pk jeremy.pub

# Install a password for the CGI script to connect to itself
yes | ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ""

# Trust the local Git SSH key.
echo -n 'command="/home/git/gitolite/src/gitolite-shell git",' > ~/.ssh/authorized_keys2
echo -n 'no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ' >> ~/.ssh/authorized_keys2
cat /home/git/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys2

# Clean up
rm -rf jeremy.pub

EOF

echo "Installation complete!"