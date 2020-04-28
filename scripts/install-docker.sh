#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

apt-get update && apt-get install -y docker-ce=18.06.2~ce~3-0~ubuntu

systemctl stop docker
cat >/etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "debug": true,
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

usermod -aG docker vagrant
docker version
docker info
# ip link
# bridge link