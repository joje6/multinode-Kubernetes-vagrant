#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

# create ceph storage class
ceph osd pool create kube 64
ceph osd pool application enable kube rbd
ceph auth get-or-create client.kube mon 'allow rw' osd 'allow class-read object_prefix rbd_children, allow rwx pool=kube' -o ceph.client.kube.keyring

CEPH_ADMIN_SECRET=$(ceph auth get-key client.admin | base64)
CEPH_USER_SECRET=$(ceph auth get-key client.kube | base64)

echo $CEPH_ADMIN_SECRET
echo $CEPH_USER_SECRET

git clone https://github.com/kubernetes-incubator/external-storage.git
sed -r -i "s/namespace: [^ ]+/namespace: kube-system/g" ./external-storage/ceph/rbd/deploy/rbac/clusterrolebinding.yaml ./external-storage/ceph/rbd/deploy/rbac/rolebinding.yaml
kubectl apply -f ./external-storage/ceph/rbd/deploy/rbac -n kube-system
# kubectl apply -f ./external-storage/ceph/rbd/deploy/non-rbac -n kube-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret
  namespace: kube-system
data:
  key: ${CEPH_ADMIN_SECRET}
type: kubernetes.io/rbd
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ceph-user-secret
  namespace: default
data:
  key: ${CEPH_USER_SECRET}
type: kubernetes.io/rbd
EOF

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
  annotations:
     storageclass.beta.kubernetes.io/is-default-class: "true"
provisioner: ceph.com/rbd
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  monitors: 172.21.12.11:6789,172.21.12.12:6789,172.21.12.13:6789
  pool: kube
  adminId: admin
  adminSecretNamespace: kube-system
  adminSecretName: ceph-secret
  userId: kube
  userSecretName: ceph-user-secret
  userSecretNamespace: default
  fsType: ext4
  imageFormat: "2"
  imageFeatures: "layering"
EOF