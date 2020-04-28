#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

# define variables
ETH_ADAPTER="enp0s8"
IP_ADDR=`ifconfig $ETH_ADAPTER | grep mask | awk '{print $2}'| cut -f2 -d:`
HOST_NAME=$(hostname -f)

echo $ETH_ADAPTER
echo $IP_ADDR
echo $HOST_NAME

# init k8s cluster
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1

kubeadm config images pull
kubeadm init --apiserver-advertise-address=$IP_ADDR --apiserver-cert-extra-sans=$IP_ADDR  --node-name $HOST_NAME --pod-network-cidr=172.16.0.0/16 --ignore-preflight-errors=all

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

# join the worker nodes to the cluster
JOIN_CMD=$(kubeadm token create --print-join-command)
ssh k8s-worker-1 "$JOIN_CMD"
ssh k8s-worker-2 "$JOIN_CMD"

# install calico
# kubectl apply -f https://docs.projectcalico.org/v3.10/manifests/calico.yaml
kubectl apply -f /assets/calico.yaml

# install flannel
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
# kubectl apply -f /assets/flannel.yaml

# install ingress-nginx
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
kubectl apply -f /assets/ingress-nginx.yaml

while [[ $(kubectl get pods -n ingress-nginx -l "app.kubernetes.io/name=ingress-nginx, app.kubernetes.io/component=controller" -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for ingress-nginx ready" && sleep 30; done
kubectl exec -it $(kubectl get pods -n ingress-nginx -l "app.kubernetes.io/name=ingress-nginx, app.kubernetes.io/component=controller" -o jsonpath='{.items[0].metadata.name}') -n ingress-nginx -- /nginx-ingress-controller --version


# install metallb
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f /assets/metallb-namespace.yaml
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl apply -f /assets/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.21.12.100-172.21.12.250
EOF


# install kubernetes-dashboard
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml
kubectl apply -f /assets/kubernetes-dashboard.yaml

# install metrics-server
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
kubectl apply -f /assets/metrics-server.yaml

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

# create dashboard ingress 
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/rewrite-target: /
    kubernetes.io/ingress.allow-http: "false"
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

cat <<EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  type: LoadBalancer
  ports:
    - port: 443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
EOF


# copy files to shared folder
INGRESS_PORT_HTTP=$(kubectl describe service/ingress-nginx-controller --namespace ingress-nginx | grep NodePort: | grep 'http ' | awk '{print $3}' | awk -F/ '{print $1}')
INGRESS_PORT_HTTPS=$(kubectl describe service/ingress-nginx-controller --namespace ingress-nginx | grep NodePort: | grep 'https ' | awk '{print $3}' | awk -F/ '{print $1}')
DASHBOARD_URL="https://${HOST_NAME}:${INGRESS_PORT_HTTPS}"
TOKEN=$(kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | awk '$1=="token:"{print $2}')

mkdir -p /basedir/shared/k8s
cp -i /etc/kubernetes/admin.conf /basedir/shared/k8s/config
echo $TOKEN > /basedir/shared/k8s/token.txt
echo $JOIN_CMD > /basedir/shared/k8s/join.sh

cat > /basedir/shared/dashboard-k8s.url <<EOF | echo
[InternetShortcut]
URL=${DASHBOARD_URL}
EOF


# print cluster information
kubectl cluster-info
kubectl get pod -o wide -A
kubectl get svc -o wide -A
echo "ingress http port is ${INGRESS_PORT_HTTP}"
echo "ingress https port is ${INGRESS_PORT_HTTPS}"
echo "dashboard url is ${DASHBOARD_URL}"
echo "token is ${TOKEN}"