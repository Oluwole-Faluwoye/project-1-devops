#!/bin/bash

set -e

echo "🚀 Updating system..."
sudo yum update -y

echo "🐳 Installing Docker..."
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker

echo "👤 Adding ec2-user to docker group..."
sudo usermod -aG docker ec2-user

echo "🔧 Installing AWS CLI v2..."

# Remove old AWS CLI v1 (if exists)
yum remove -y aws-cli || true
rm -f /usr/bin/aws || true

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

# Ensure correct binary is used
ln -sf /usr/local/bin/aws /usr/bin/aws

# Verify
aws --version

echo "📦 Installing kubectl..."

curl -L -o /usr/local/bin/kubectl \
  https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x /usr/local/bin/kubectl

echo "📁 Creating Docker volumes..."
docker volume create jenkins_home
docker volume create sonarqube_data
docker volume create sonarqube_logs
docker volume create sonarqube_extensions

echo "🚀 Starting Jenkins container..."
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

echo "🚀 Starting SonarQube container..."
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts

echo "⏳ Waiting for services to start..."
sleep 30

echo "🔑 Jenkins initial password:"
docker logs jenkins | grep -A 5 "Please use the following password"

echo "🌐 Access Jenkins: http://<EC2-PUBLIC-IP>:8080"
echo "🌐 Access SonarQube: http://<EC2-PUBLIC-IP>:9000 (admin/admin)"

echo "✅ Setup complete!"
echo "⚠️ IMPORTANT: Log out and SSH back in for Docker permissions to apply"