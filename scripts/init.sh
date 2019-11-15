#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

# define variables
IP_ADDR=`ifconfig enp0s8 | grep mask | awk '{print $2}'| cut -f2 -d:`
HOST_NAME=$(hostname -f)

echo $IP_ADDR
echo $HOST_NAME

# init k8s cluster
sysctl net.bridge.bridge-nf-call-iptables=1
kubeadm init --apiserver-advertise-address=$IP_ADDR --apiserver-cert-extra-sans=$IP_ADDR  --node-name $HOST_NAME --pod-network-cidr=192.168.0.0/16

# copy kube config to user:root
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# copy kube config to user:vagrant
sudo --user=vagrant mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config

# copy ssh key
mkdir -p /root/.ssh
cp .ssh/id_rsa .ssh/id_rsa.pub /root/.ssh
cp .ssh/id_rsa.pub /root/.ssh/authorized_keys
ssh-keyscan -H -t rsa k8s-worker-1 k8s-worker-2 > /root/.ssh/known_hosts

# extract join command
JOIN_CMD=$(kubeadm token create --print-join-command)
echo $JOIN_CMD

# join the worker nodes to the cluster
ssh k8s-worker-1 "$JOIN_CMD"
ssh k8s-worker-2 "$JOIN_CMD"

# install calico
kubectl apply -f https://docs.projectcalico.org/v3.10/manifests/calico.yaml

# install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/service-nodeport.yaml

# install kubernetes-dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml

# create and add tls key & crt
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=${HOST_NAME}/O=${HOST_NAME}"
kubectl create secret tls tls-secret --key tls.key --cert tls.crt -n kube-system

# create admin user
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
EOF

# print admin token
TOKEN=$(kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | awk '$1=="token:"{print $2}')

# print cluster information
kubectl cluster-info

# create dashboard ingress 
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    # nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.org/ssl-backend: "kubernetes-dashboard"
    kubernetes.io/ingress.allow-http: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "100M"
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  tls:
  - secretName: tls-secret
  rules:
  - host: ${HOST_NAME}
    http:
      paths:
      - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
EOF

# print services and pods
kubectl get pod -o wide -A
kubectl get svc -o wide -A

DASHBOARD_PORT=$(kubectl describe service/ingress-nginx --namespace ingress-nginx | grep NodePort: | grep https | awk '{print $3}' | awk -F/ '{print $1}')
DASHBOARD_URL="https://${HOST_NAME}:${DASHBOARD_PORT}"

# copy files to shared folder
rm -rf /vagrant/shared
mkdir -p /vagrant/shared
cp -i /etc/kubernetes/admin.conf /vagrant/shared/config
echo $TOKEN > /vagrant/shared/token.txt
echo $JOIN_CMD > /vagrant/shared/join.sh

cat > /vagrant/shared/dashboard.url <<EOF | echo
[InternetShortcut]
URL=${DASHBOARD_URL}
EOF