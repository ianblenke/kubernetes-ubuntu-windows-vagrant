#!/bin/bash
set -eux

apiserver_advertise_address=$1
pod_network_cidr=$2
service_cidr=$3
service_dns_domain=$4

# initialize kubernetes.
mkdir -p /vagrant/tmp
kubeadm init \
    --apiserver-advertise-address=$apiserver_advertise_address \
    --pod-network-cidr=$pod_network_cidr \
    --service-cidr=$service_cidr \
    --service-dns-domain=$service_dns_domain
# save the kubeadm join command which will later be used to add
# the workers to the cluster. this token is valid for one day.
kubeadm token create --print-join-command >/vagrant/tmp/kubeadm-join.sh

# configure kubectl in the root and vagrant accounts with kubernetes superuser privileges.
for home in /root /home/vagrant; do
    o=$(stat -c '%U' $home)
    g=$(stat -c '%G' $home)
    install -d -m 700 -o $o -g $g $home/.kube
    install -m 600 -o $o -g $g /etc/kubernetes/admin.conf $home/.kube/config
done

# also save the kubectl configuration on the host, so we can access it there.
cp /etc/kubernetes/admin.conf /vagrant/tmp

# install the flannel (in vxlan mode) cni addon as the pod network driver.
# see https://docs.microsoft.com/en-us/virtualization/windowscontainers/kubernetes/network-topologies
sed -E "s,@@pod_network_cidr@@,$pod_network_cidr,g" /vagrant/kube-flannel.yml | kubectl apply -f -

# make sure the kube-proxy daemonset does not run on windows.
# NB as of kubernetes 1.14.0 the kube-proxy daemonset can only
#    run on linux but its missing the nodeSelector.
# TODO see why is this: Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
kubectl \
  -n kube-system \
  get \
  ds/kube-proxy \
  -o json \
  | jq '.spec.template.spec.nodeSelector."kubernetes.io/os"="linux"' \
  | kubectl apply -f -

# wait for this node to be Ready.
# e.g. km1     Ready     master    35m       v1.14.0
$SHELL -c 'node_name=$(hostname); while [ -z "$(kubectl get nodes $node_name | grep -E "$node_name\s+Ready\s+")" ]; do kubectl get nodes ; sleep 3; done'

# wait for the kube-dns pod to be Running.
# e.g. coredns-fb8b8dccf-rh4fg   1/1     Running   0          33m
$SHELL -c 'while [ -z "$(kubectl get pods --selector k8s-app=kube-dns --namespace kube-system | grep -E "\s+Running\s+")" ]; do kubectl get nodes ; sleep 3; done'

# install the kubernetes dashboard.
# see https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/00_dashboard-namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/01_dashboard-serviceaccount.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/02_dashboard-service.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/03_dashboard-secret.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/04_dashboard-configmap.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/05_dashboard-rbac.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/06_dashboard-deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/07_scraper-service.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/08_scraper-deployment.yaml

# create the admin user.
# see https://github.com/kubernetes/dashboard/wiki/Creating-sample-user
# see https://github.com/kubernetes/dashboard/wiki/Access-control
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin
  namespace: kube-system
EOF
# save the admin token.
kubectl \
  -n kube-system \
  get \
  secret \
  $(kubectl -n kube-system get secret | grep admin-token- | awk '{print $1}') \
  -o json | jq -r .data.token | base64 --decode \
  >/vagrant/tmp/admin-token.txt

# list all nodes and pods.
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# show cluster-info.
kubectl cluster-info

# uncomment the next line if you want let the master node run user pods (not recommended).
#kubectl taint nodes --all node-role.kubernetes.io/master-

# list bootstrap tokens.
kubeadm token list

# list system secrets.
kubectl -n kube-system get secret

# list services.
kubectl get svc

# list the kubernetes configuration files.
find /etc/kubernetes

# show listening ports.
ss -n --tcp --listening --processes

# show network routes.
ip route

# show running containers.
docker ps --format '{{.Image}} {{.Command}}' --no-trunc
for ns in $(ctr namespaces list -q); do ctr -n $ns container list | xargs -L1 -I% echo "$ns %"; done
