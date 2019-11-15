#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

# install docker
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update && apt-get install -y docker-ce=18.06.2~ce~3-0~ubuntu

# install k8s
apt-get install -y apt-transport-https software-properties-common
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-$(lsb_release -cs) main"
add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
apt-get update && apt-get install -y kubelet kubeadm kubectl kubernetes-cni

# swap off
swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# config docker
systemctl stop docker
cat >/etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "debug": false,
    "labels": [
        "os=linux"
    ],
    "hosts": [
        "unix://",
        "tcp://0.0.0.0:2375"
    ]
}
EOF

sed -i -E 's,^(ExecStart=/usr/bin/dockerd).*,\1,' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl start docker

# add vagrant user to docker group
usermod -aG docker vagrant

# print info
docker version
docker info