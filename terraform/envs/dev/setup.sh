#!/bin/bash

set -e

echo "🚀 Setting AWS region..."
export AWS_DEFAULT_REGION=us-east-1

echo "🚀 Updating system packages..."
sudo yum update -y

# ---------------------------------------------------
# Install Docker
# ---------------------------------------------------

echo "🐳 Installing Docker..."

sudo yum install -y docker

sudo systemctl start docker
sudo systemctl enable docker

echo "👤 Adding ec2-user to docker group..."
sudo usermod -aG docker ec2-user

# ---------------------------------------------------
# Install AWS CLI v2 ON HOST
# Needed for ECR login on EC2 host
# ---------------------------------------------------

echo "🔧 Installing AWS CLI v2 on host..."

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
-o "awscliv2.zip"

unzip -q awscliv2.zip

sudo ./aws/install --update

# ---------------------------------------------------
# Mount Dedicated Persistent EBS Volume
# ---------------------------------------------------

echo "💾 Checking for dedicated EBS volume..."

DEVICE="/dev/xvdf"

if [ -b "$DEVICE" ]; then

    echo "✅ EBS volume detected."

    # ------------------------------------------------
    # Format only if filesystem does not exist
    # Prevents wiping Jenkins data
    # ------------------------------------------------

    if ! sudo blkid $DEVICE; then

        echo "🧱 Formatting EBS volume..."

        sudo mkfs -t xfs $DEVICE

    else

        echo "✅ Existing filesystem detected."
    fi

    # ------------------------------------------------
    # Create mount point
    # ------------------------------------------------

    echo "📂 Creating /data mount point..."

    sudo mkdir -p /data

    # ------------------------------------------------
    # Mount EBS volume
    # ------------------------------------------------

    echo "🔗 Mounting EBS volume to /data..."

    sudo mount $DEVICE /data || true

    # ------------------------------------------------
    # Persist mount after reboot
    # ------------------------------------------------

    echo "📝 Updating /etc/fstab..."

    UUID=$(sudo blkid -s UUID -o value $DEVICE)

    grep -q "$UUID" /etc/fstab || \
    echo "UUID=$UUID /data xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab

else

    echo "⚠️ No dedicated EBS volume detected."
    echo "⚠️ Falling back to root volume storage."

fi

# ---------------------------------------------------
# Create Persistent Directories
# ---------------------------------------------------

echo "📁 Creating persistent directories..."

sudo mkdir -p /data/jenkins
sudo mkdir -p /data/sonarqube/data
sudo mkdir -p /data/sonarqube/logs
sudo mkdir -p /data/sonarqube/extensions

# ---------------------------------------------------
# Fix Permissions Automatically
# Jenkins and SonarQube both run as UID 1000
# ---------------------------------------------------

echo "🔐 Setting correct ownership and permissions..."

sudo chown -R 1000:1000 /data/jenkins
sudo chmod -R 775 /data/jenkins

sudo chown -R 1000:1000 /data/sonarqube
sudo chmod -R 775 /data/sonarqube

# ---------------------------------------------------
# Create Docker Network
# ---------------------------------------------------

echo "🌐 Creating shared Docker network..."

docker network create devops-network || true

# ---------------------------------------------------
# Login to ECR
# ---------------------------------------------------

echo "🔐 Logging into ECR..."

aws ecr get-login-password --region us-east-1 \
| docker login \
--username AWS \
--password-stdin 761018849945.dkr.ecr.us-east-1.amazonaws.com

# ---------------------------------------------------
# Pull Jenkins Image
# ---------------------------------------------------

echo "📥 Pulling Jenkins image from ECR..."

docker pull 761018849945.dkr.ecr.us-east-1.amazonaws.com/jenkins:v1

# ---------------------------------------------------
# Pull SonarQube Image
# ---------------------------------------------------

echo "📥 Pulling SonarQube image..."

docker pull sonarqube:lts

# ---------------------------------------------------
# Remove Existing Containers
# ---------------------------------------------------

if [ "$(docker ps -aq -f name=jenkins)" ]; then
    echo "⚠️ Jenkins container already exists."
    echo "⚠️ Removing old Jenkins container..."
    docker rm -f jenkins
fi

if [ "$(docker ps -aq -f name=sonarqube)" ]; then
    echo "⚠️ SonarQube container already exists."
    echo "⚠️ Removing old SonarQube container..."
    docker rm -f sonarqube
fi

# ---------------------------------------------------
# Start Jenkins Container
# ---------------------------------------------------

echo "🚀 Starting Jenkins container..."

docker run -d \
  --name jenkins \
  --network devops-network \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /data/jenkins:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  761018849945.dkr.ecr.us-east-1.amazonaws.com/jenkins:v1

# ---------------------------------------------------
# Start SonarQube Container
# ---------------------------------------------------

echo "🚀 Starting SonarQube container..."

docker run -d \
  --name sonarqube \
  --network devops-network \
  --restart unless-stopped \
  -p 9000:9000 \
  -v /data/sonarqube/data:/opt/sonarqube/data \
  -v /data/sonarqube/logs:/opt/sonarqube/logs \
  -v /data/sonarqube/extensions:/opt/sonarqube/extensions \
  sonarqube:lts

# ---------------------------------------------------
# Wait for Services
# ---------------------------------------------------

echo "⏳ Waiting for services to initialize..."

sleep 40

# ---------------------------------------------------
# Health Checks
# ---------------------------------------------------

echo "🩺 Checking Jenkins health..."

curl -f http://localhost:8080/login \
&& echo "✅ Jenkins is healthy" \
|| echo "❌ Jenkins health check failed"

echo "🩺 Checking SonarQube health..."

curl -f http://localhost:9000 \
&& echo "✅ SonarQube is healthy" \
|| echo "❌ SonarQube health check failed"

# ---------------------------------------------------
# Verify Running Containers
# ---------------------------------------------------

echo "🔍 Running containers..."

docker ps

# ---------------------------------------------------
# Verify Tools Inside Jenkins
# ---------------------------------------------------

echo "🔍 Verifying tools inside Jenkins container..."

docker exec jenkins docker --version
docker exec jenkins aws --version
docker exec jenkins kubectl version --client
docker exec jenkins helm version
docker exec jenkins node --version

# ---------------------------------------------------
# Jenkins Initial Password
# ---------------------------------------------------

echo "🔑 Jenkins initial admin password:"

docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword || true

# ---------------------------------------------------
# Final Output
# ---------------------------------------------------

echo ""
echo "✅ Setup Complete!"
echo ""

echo "🌐 Jenkins URL:"
echo "http://<EC2-PUBLIC-IP>:8080"

echo ""
echo "🌐 SonarQube URL:"
echo "http://<EC2-PUBLIC-IP>:9000"

echo ""
echo "🔔 SonarQube Default Credentials:"
echo "Username: admin"
echo "Password: admin"

echo ""
echo "📁 Persistent Data Locations:"
echo "/data/jenkins"
echo "/data/sonarqube"

echo ""
echo "⚠️ IMPORTANT:"
echo "- Re-login to SSH after script completes"
echo "- Jenkins container already includes:"
echo "  ✔ Helm"
echo "  ✔ kubectl"
echo "  ✔ AWS CLI v2"
echo "  ✔ Docker CLI"
echo "  ✔ Node.js"

echo ""
echo "🔗 SonarQube Webhook:"
echo "http://jenkins:8080/sonarqube-webhook/"

echo ""
echo "🔗 GitHub Webhook:"
echo "http://<EC2-PUBLIC-IP>:8080/github-webhook/"