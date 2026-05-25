#!/bin/bash

set -e

echo "🚀 Setting AWS region..."
export AWS_DEFAULT_REGION=us-east-1

echo "🚀 Updating system packages..."
sudo yum update -y

echo "🐳 Installing Docker..."
sudo yum install -y docker

sudo systemctl start docker
sudo systemctl enable docker

echo "👤 Adding ec2-user to docker group..."
sudo usermod -aG docker ec2-user

echo "🔧 Installing AWS CLI v2..."

# Remove old AWS CLI if exists
sudo yum remove -y aws-cli || true
sudo rm -f /usr/bin/aws || true

# Download and install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip -q awscliv2.zip

sudo ./aws/install

# Ensure correct path
sudo ln -sf /usr/local/bin/aws /usr/bin/aws

echo "✅ AWS CLI Version:"
aws --version

echo "📦 Installing kubectl..."

curl -L -o /usr/local/bin/kubectl \
https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x /usr/local/bin/kubectl

echo "✅ kubectl Version:"
kubectl version --client

echo "📁 Creating Docker volumes..."

docker volume create jenkins_home
docker volume create sonarqube_data
docker volume create sonarqube_logs
docker volume create sonarqube_extensions

echo "🌐 Creating shared Docker network..."
docker network create devops-network || true

echo "🔐 Logging into ECR..."

aws ecr get-login-password --region us-east-1 \
| docker login \
--username AWS \
--password-stdin 761018849945.dkr.ecr.us-east-1.amazonaws.com

echo "📥 Pulling Jenkins image from ECR..."

docker pull 761018849945.dkr.ecr.us-east-1.amazonaws.com/jenkins:latest

echo "🧹 Removing old containers if they exist..."

docker rm -f jenkins || true
docker rm -f sonarqube || true

echo "🚀 Starting Jenkins container..."

docker run -d \
  --name jenkins \
  --network devops-network \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  761018849945.dkr.ecr.us-east-1.amazonaws.com/jenkins:latest

echo "🚀 Starting SonarQube container..."

docker run -d \
  --name sonarqube \
  --network devops-network \
  --restart unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts

echo "⏳ Waiting for services to initialize..."
sleep 40

echo "🔍 Verifying running containers..."
docker ps

echo "🌐 Verifying Docker network..."
docker network inspect devops-network

echo "🔑 Jenkins initial admin password:"
docker logs jenkins | grep -A 5 "Please use the following password" || true

echo "✅ Setup complete!"

echo "🌐 Jenkins URL:"
echo "http://<EC2-PUBLIC-IP>:8080"

echo "🌐 SonarQube URL:"
echo "http://<EC2-PUBLIC-IP>:9000"

echo "🔔 SonarQube default credentials:"
echo "Username: admin"
echo "Password: admin"

echo "⚠️ IMPORTANT:"
echo "- Log out and SSH back in for Docker group permissions to fully apply"
echo "- Configure SonarQube webhook using:"
echo "  http://jenkins:8080/sonarqube-webhook/"
echo "- Configure GitHub webhook using:"
echo "  http://<EC2-PUBLIC-IP>:8080/github-webhook/"