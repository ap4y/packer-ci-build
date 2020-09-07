#!/usr/bin/env bash

set -eu

source "${ENV_FILEPATH}"
export 'IPROUTE_BRANCH'=${IPROUTE_BRANCH:-"static-data"}
export 'IPROUTE_GIT'=${IPROUTE_GIT:-https://github.com/cilium/iproute2}
export 'GUESTADDITIONS'=${GUESTADDITIONS:-""}
export 'HUBBLE_SHA'=${HUBBLE_SHA:-"186fa10"}
export 'HUBBLE_GIT'=${HUBBLE_GIT:-https://github.com/cilium/hubble}
NETNEXT="${NETNEXT:-false}"

# Install nodejs and npm, needed for the cilium rtd sphinx theme
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://deb.nodesource.com/node_12.x \
   $(lsb_release -cs) \
   main"
sudo apt-get update
sudo apt-get install -y nodejs

# Install protoc from github release, as protobuf-compiler version in apt is quite old (e.g 3.0.0-9.1ubuntu1)
cd /tmp
wget -nv https://github.com/protocolbuffers/protobuf/releases/download/v3.11.4/protoc-3.11.4-linux-x86_64.zip
unzip -p protoc-3.11.4-linux-x86_64.zip bin/protoc > protoc
sudo chmod +x protoc
sudo cp protoc /usr/bin
rm -rf protoc-3.11.4-linux-x86_64.zip protoc

# Install nsenter for kubernetes
cd /tmp
wget -nv https://www.kernel.org/pub/linux/utils/util-linux/v2.30/util-linux-2.30.1.tar.gz
tar -xvzf util-linux-2.30.1.tar.gz
cd util-linux-2.30.1
./autogen.sh
./configure --without-python --disable-all-programs --enable-nsenter
make nsenter
sudo cp nsenter /usr/bin
cd ..
rm -fr util-linux-2.30.1/ util-linux-2.30.1.tar.gz

# Install conntrack for kubeadm >= 1.18

sudo apt-get install -y conntrack

# Install clang/llvm
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
sudo add-apt-repository "deb http://apt.llvm.org/bionic/   llvm-toolchain-bionic-11  main"
sudo apt-get update
sudo apt-get install -y clang-11
sudo ln -s /usr/bin/clang-11 /usr/bin/clang
sudo ln -s /usr/bin/llc-11 /usr/bin/llc

# Documentation dependencies
sudo -H pip3 install -r https://raw.githubusercontent.com/cilium/cilium/master/Documentation/requirements.txt

#IP Route
cd /tmp
git clone -b ${IPROUTE_BRANCH} ${IPROUTE_GIT}
cd /tmp/iproute2
./configure
make -j `getconf _NPROCESSORS_ONLN`
make install

#Install Golang
cd /tmp/
sudo curl -Sslk -o go.tar.gz \
    "https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz"
sudo tar -C /usr/local -xzf go.tar.gz
sudo rm go.tar.gz
sudo ln -s /usr/local/go/bin/* /usr/local/bin/
go version

#Install docker compose
sudo sh -c "curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
sudo chmod +x /usr/local/bin/docker-compose

#ETCD installation
wget -nv "https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
tar -xf "etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
sudo mv "etcd-${ETCD_VERSION}-linux-amd64/etcd"* /usr/bin/

sudo tee /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/bin/etcd --name=cilium --data-dir=/var/etcd/cilium --advertise-client-urls=http://192.168.36.11:9732 --listen-client-urls=http://0.0.0.0:9732 --listen-peer-urls=http://0.0.0.0:9733
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable etcd
sudo systemctl start etcd

# Install sonobuoy
cd /tmp
wget "https://github.com/heptio/sonobuoy/releases/download/v${SONOBUOY_VERSION}/sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz"
tar -xf "sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz"
sudo mv sonobuoy /usr/bin

# Install hubble
git clone ${HUBBLE_GIT}
cd /tmp/hubble
git reset --hard ${HUBBLE_SHA}
make
sudo make BINDIR=/usr/bin install
