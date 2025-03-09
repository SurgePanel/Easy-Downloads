#!/bin/bash

sudo apt update && sudo apt upgrade -y
sudo apt install -y git
sudo adduser --gecos "DevStack" --disabled-password stack
echo "stack:stack" | sudo chpasswd

sudo su - stack
cd /home/stack/
git clone https://opendev.org/openstack/devstack.git
cd devstack

cat <<EOL > local.conf
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=\$ADMIN_PASSWORD
RABBIT_PASSWORD=\$ADMIN_PASSWORD
SERVICE_PASSWORD=\$ADMIN_PASSWORD
HOST_IP=127.0.0.1
EOL

./stack.sh

echo "OpenStack installation complete!"
echo "Access the OpenStack dashboard at: http://127.0.0.1/dashboard"
echo "Username: admin"
echo "Password: secret"