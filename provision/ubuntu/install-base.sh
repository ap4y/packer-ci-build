#!/usr/bin/env bash

set -eu

# Add repos
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# wget https://packages.cloud.google.com/apt/doc/apt-key.gpg
# apt-key add apt-key.gpg

#Install packages
echo "Provision a new server"
sudo apt-get update
sudo apt-get install -y --allow-downgrades \
    curl jq apt-transport-https htop bmon \
    linux-tools-common linux-tools-generic \
    ca-certificates libelf-dev \
    software-properties-common \
    dh-golang devscripts fakeroot \
    dh-make libmnl-dev git \
    libdistro-info-perl libssl-dev \
    dh-systemd build-essential \
    gcc make git-buildpackage \
    pkg-config bison flex \
    zip g++ zlib1g-dev unzip python \
    libtool cmake coreutils m4 automake \
    libprotobuf-dev libyaml-cpp-dev \
    socat pv tmux bc gcc-multilib binutils-dev \
    binutils wget rsync ifupdown \
    python3-sphinx python3-pip \
    libncurses5-dev libslang2-dev gettext \
    libselinux1-dev debhelper lsb-release \
    po-debconf autoconf autopoint moreutils \
    libseccomp2 libenchant1c2a ninja-build \
    golang-cfssl ntp docker-ce

sudo usermod -aG docker vagrant

# Clean all downloaded packages
sudo apt-get -y clean
sudo apt-get -y autoclean

# Disable unattended-upgrades to prevent it from holding the dpkg frontend lock
systemctl mask apt-daily.service apt-daily-upgrade.service
sudo systemctl disable unattended-upgrades.service
sudo systemctl stop unattended-upgrades.service

# Disable systemd-resolved service
# https://github.com/cilium/cilium/issues/2750
sudo systemctl disable systemd-resolved.service
sudo service systemd-resolved stop

sudo unlink /etc/resolv.conf || true

sudo tee /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# CoreDumps https://github.com/cilium/cilium/issues/3399
sudo systemctl disable apport.service
sudo sh -c 'echo "sysctl kernel.core_pattern=/tmp/core.%e.%p.%t" > /etc/sysctl.d/66-core-pattern.conf'

# journald configuration
sudo bash -c "echo RateLimitIntervalSec=1s >> /etc/systemd/journald.conf"
sudo bash -c "echo RateLimitBurst=10000 >> /etc/systemd/journald.conf"
sudo systemctl restart systemd-journald

# Kernel parameters
sudo sh -c 'echo "kernel.randomize_va_space=0" > /etc/sysctl.d/67-randomize_va_space.conf'
