# Multinode Kubernetes on Vagrant

Configure a Kubernetes cluster with 1 master and 2 worker nodes. 

## Prerequisites

[Vagrant](http://www.vagrantup.com/downloads.html) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads) are required. And based on macOS.

```sh
$ brew cask install virtualbox
$ brew cask install vagrant
$ brew cask install vagrant-manager
$ vagrant plugin install vagrant-hostmanager
```

## Start VM

```sh
$ vagrant up
```

## Login to Node
```sh
# login to master node
$ vagrant ssh
# login to worker node
$ vagrant ssh k8s-worker-1
$ vagrant ssh k8s-worker-2
```

## Access the Dashboard
`vagrant up` completes successfully, you can access the dashboard. It may take a few more minutes for ingress and dashboard pods to finish working properly.

You can find the dashboard access URL in the folder below. (config file and token is in the same directory)
`/shared/dashboard.url`
`/shared/config`
`/shared/token.txt`

## Using the local kubernetes client

```sh
$ brew install kubernetes-cli
$ mkdir -p ~/.kube
$ cp ./shared/config ~/.kube/config
# make sure you are connected
$ kubectl get nodes
```

## How to use

https://kubernetes.io/docs/home/

## Destroy

When you're all done, tell Vagrant to destroy the VMs.

```console
$ vagrant destroy -f
```