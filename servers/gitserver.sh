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
DEBIAN_FRONTEND=noninteractive apt-get install -y git python php5 python-pip \
  build-essential python-dev libcap-dev

cd /home/git

# Fetch the IPython submission script.
rm -rf lsda-management
git clone https://github.com/fatlotus/lsda-management.git
pip install -r lsda-management/submitter_requrements.txt 2>/dev/null

# Install Gitlist
rm -rf /var/gitlist || true
wget https://s3.amazonaws.com/gitlist/gitlist-0.4.0.tar.gz
tar xvf gitlist-0.4.0.tar.gz -C /var
cat > /var/gitlist/config.ini <<EOF
[git]
client = '/usr/bin/git';
default_branch = 'master';
repositories[] = '/home/git/repositories';

[app]
debug = false
cache = true

[Date]
timezone = CST
EOF

# Ensure that Gitlist works in a subdirectory.
cat > /var/gitlist/.htaccess <<EOF

<Files config.ini>
  Order Allow,Deny
  Deny from All
</Files>

EOF
mkdir -p /var/gitlist/cache
chown git:git /var/gitlist/cache
chmod 0777 /var/gitlist/cache
rm gitlist-0.4.0.tar.gz

su - git <<EOF

set -e -x

# Include my public key in the setup process.
cat > jeremy.pub <<NEOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCpZxfYDGv07zdwv2Qa7SLIUi74rhR6D7y41uVbo6SUn3EbJbc7rSgO+CTgQTbbTNn9eEjMxQ3Q2QRt9FdyTRT6Gn607gtqi1uKkuRkkIxDTGNmRgrbC55M8Q07u8Z1PJvOmd5MnP3Et2dQdVJ1UCawNQLuktPup7sLBafsPHiDUnjTrI61x0E2fnyXOOlr1NmLWYQ4Plp8lQhOF9Y1hx8et3k0/y/r/TaVa5VI12kJ11f0vvvaZhAqKdbEKZE1XOYVD8ZrH8qs/x1a807Ilcvvr6LJ0TnZ3aUYL80cBT3IbCNwDgqytGXMCyBh9KTnjMB4neIkUYGkiyCDfzhQPzyr spectre-secure
NEOF

# Wipe out any existing keys (since we mess with this file later)
rm -rf ~/.ssh/authorized_keys*

# Fetch Gitolite
rm -rf gitolite
git clone git://github.com/sitaramc/gitolite

# Create a triggering post-receive VREF.
ln -s /home/git/lsda-management/submitter.py \\
  ~/gitolite/src/VREF/submit_to_lsda

# Install a quota update VREF.
cat > ~/gitolite/src/VREF/quota_copier <<EOF2
#!/bin/bash -ex

python /home/git/lsda-management/quota_copier.py \\
  --zookeeper zookeeper.lsda.cs.uchicago.edu \\
  --config /home/git/.gitolite/conf/quotas.yaml

EOF2
chmod +x ~/gitolite/src/VREF/quota_copier

# Install Gitolite globally the second time.
#   Trust me on this, I'm from the past. This is the only way.
gitolite/src/gitolite setup -pk jeremy.pub
rm -rf /home/git/repositories/testing.git

# Install a password for the CGI script to connect to itself
yes | ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ""

# Trust the local Git SSH key.
echo -n 'command="/home/git/gitolite/src/gitolite-shell git",' > ~/.ssh/authorized_keys2
echo -n 'no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ' >> ~/.ssh/authorized_keys2
cat /home/git/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys2

# Install the add_response.cgi script.
rm -rf /home/git/repositories/add_response.cgi
cp lsda-management/add_response.cgi /home/git/repositories
chmod +x /home/git/repositories/add_response.cgi

# Clean up
rm -rf jeremy.pub

EOF

echo "Installation complete!"