#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

apt-get install -y apt-transport-https software-properties-common
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-$(lsb_release -cs) main"
add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
apt-get update && apt-get install -y kubelet kubeadm kubectl kubernetes-cni

swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
