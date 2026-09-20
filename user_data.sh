#!/bin/bash
# user_data.sh — runs once, automatically, when the EC2 instance boots.
# This is what makes the box arrive "ready" instead of you SSHing in and
# typing 15 install commands by hand.
set -e

apt-get update -y

# --- Docker ---
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# --- Jenkins ---
apt-get install -y openjdk-17-jre
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins
usermod -aG docker jenkins
systemctl enable jenkins
systemctl start jenkins

# --- k3s (lightweight Kubernetes) ---
curl -sfL https://get.k3s.io | sh -
# Make the cluster's config readable so kubectl works without sudo every time
chmod 644 /etc/rancher/k3s/k3s.yaml

# --- Trivy (container vulnerability scanner) ---
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
  sh -s -- -b /usr/local/bin
