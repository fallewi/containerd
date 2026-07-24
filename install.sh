#!/bin/bash
apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
apt-get install -y apt-transport-https ca-certificates curl gpg
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet
set -euo pipefail

echo "=== Mise à jour du système ==="
apt-get update
apt-get upgrade -y

echo " === Installation de HELM ==="
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

echo "=== Installation des dépendances ==="
apt-get install -y \
    curl \
    wget \
    git \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https

echo "=== Ajout du dépôt Docker ==="
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
chmod a+r /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update


echo "=== Installation de Containerd ==="
apt-get install -y containerd.io

echo "=== Génération de la configuration ==="
mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

echo "=== Configuration SystemdCgroup ==="
sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

echo "=== Redémarrage du service ==="
systemctl daemon-reload
systemctl enable containerd
systemctl restart containerd

echo "=== Vérification ==="
systemctl --no-pager --full status containerd

echo
echo "Containerd installé avec succès."
echo "Version :"
containerd --version

echo "=== Configuration Kernel Kubernetes ==="

cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

/usr/sbin/modprobe overlay
/usr/sbin/modprobe br_netfilter

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

echo "=== Désactivation du swap ==="
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
ctr version
VERSION="v1.36.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
crictl info


echo "=== Remove Machine-Id on template VM ==="
truncate -s 0 /etc/machine-id
