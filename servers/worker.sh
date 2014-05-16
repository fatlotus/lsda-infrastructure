#!/bin/bash
#
# Installs the worker node software on this node.
#
# Author: Jeremy Archer <jarcher@uchicago.edu>
# Date: 9 December 2013.
#

set -e -x

# Stop any existing worker nodes.
stop lsda || true

# Prepare system for install.
useradd -m -r lsda || true
useradd -m -r sandbox || true

# Allow lsda to jump into the sandbox.
cat > /etc/sudoers.d/lsda <<EOF
lsda ALL=(root) NOPASSWD: /worker/sandbox.py *
lsda ALL=(root) NOPASSWD: /bin/chown lsda /mnt
lsda ALL=(root) NOPASSWD: /bin/chmod 0777 /mnt
lsda ALL=(root) NOPASSWD: /bin/mount /mnt
lsda ALL=(root) NOPASSWD: /sbin/shutdown -h now
EOF
chmod 0440 /etc/sudoers.d/lsda
cat /etc/sudoers.d/lsda

# Install requisite software.
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y git python python-distribute \
  python-pip build-essential python-dev python-numpy python-scipy \
  python-matplotlib python-pandas python-sympy libfftw3-dev python-matplotlib \
  libfreetype6-dev mdadm btrfs-tools

# Create worker environment.
rm -rf /worker || true
mkdir -p /worker
cd /worker
git clone https://github.com/fatlotus/lsda-management.git .

pip install -r /worker/requirements.txt
pip install --upgrade --no-deps git+https://github.com/fatlotus/runipy.git
pip install --upgrade --no-deps \
  git+https://github.com/fatlotus/lsda-data-access-layer.git

pip install -U distribute

if [ "x$QUICK" = x ]; then
  pip install git+https://github.com/fatlotus/matplotlib.git
  pip install --upgrade --no-deps \
    git+https://github.com/fatlotus/matplotlib.git
fi

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
   "wishes": {
       "bucket": "ml-wishes"
   },
   "sou": {
       "bucket": "ml-sou"
   },
   "digits": {
       "bucket": "ml-digits"
   },
   "genomes": {
       "bucket": "ml-genomics"
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

cat > /etc/boto.conf <<EOF
[Boto]
metadata_service_num_attempts = 5
EOF

cat > /etc/sysctl.conf <<EOF
net.ipv4.tcp_wmem = 4096 16384 512000
net.ipv4.tcp_wmem = 4096 16384 512000
EOF

sysctl -p

if [ "x$CHANNEL" = "x" ]; then
  CHANNEL=stable
fi

# Configure daemons
cat > /etc/init/lsda.conf <<EOF
description "Runs an Python LSDA Worker Process"
author "Jeremy Archer <jarcher@uchicago.edu>"

respawn

start on stopping mnt-fixer 

setuid lsda
setgid lsda

limit nofile 16384 16384

script
  python /worker/management.py \\
    --amqp=amqp.lsda.cs.uchicago.edu \\
    --zookeeper=zookeeper.lsda.cs.uchicago.edu \\
    --queue=$CHANNEL
end script
EOF

cat > /etc/init/mnt-fixer.conf <<EOF
description "Ensures that RAID0 is properly configured on boot."
author "Jeremy Archer <jarcher@uchicago.edu>"

start on filesystem

script
  if [ -b /dev/xvdc ]; then
    umount /mnt || true
    mkfs.btrfs -d raid0 /dev/xvdb /dev/xvdc
    mount -o compress -t btrfs /dev/xvdb /mnt
    chown -R lsda:lsda /mnt
    chmod 0755 /mnt
  fi
end script
EOF

stop lsda || true
start mnt-fixer