#!/bin/bash
echo " ***You can add bash scripts to install prerequisite software in you image in bootstrap.sh file ***"

curl -sfL https://rancher-mirror.oss-cn-beijing.aliyuncs.com/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -
sudo chown ubuntu:ubuntu /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo wget https://mirrors.onwalk.net/tools/linux-amd64/helm.tar.gz && sudo tar -xvpf helm.tar.gz -C /usr/local/bin/
sudo chmod 755 /usr/local/bin/helm
helm repo add neuvector https://neuvector.github.io/neuvector-helm/
#helm repo add nginx-stable https://helm.nginx.com/stable
helm repo up
#helm install ingress nginx-stable/nginx-ingress --set controller.enableCustomResources=false --set controller.appprotect.enable=false --set controller.hostNetwork=true
sleep 30
kubectl create namespace neuvector

