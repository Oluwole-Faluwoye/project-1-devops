# End-to-End DevOps Project Architecture Explained

# Overview

This project demonstrates a complete cloud-native DevOps pipeline using:

* GitHub
* Jenkins
* Docker
* SonarQube
* Trivy
* Amazon ECR
* Amazon EKS
* Helm
* Kubernetes
* Terraform
* AWS EC2

The goal of this project was not only to deploy an application to Kubernetes, but to build a reusable, production-style CI/CD platform that can be reused for future projects.

---

# Final Architecture

```text
Developer Pushes Code to GitHub
                ↓
           Jenkins Pipeline
                ↓
          Build Node.js App
                ↓
           SonarQube Scan
                ↓
         Quality Gate Check
                ↓
          Docker Image Build
                ↓
         Trivy Security Scan
                ↓
            Push to AWS ECR
                ↓
          Helm Deployment
                ↓
             Amazon EKS
                ↓
          Kubernetes Pods
```


---
Best Architecture to Persis our Jenkins Instance Data such that we can delete or terminate our instance and still have our data to spin up another instance say we finish our build, all our credentials and configurations, jobs will be persisted inside an EBS volume and we can spin up another instance later when we want to run any job   ( Start from where you stopped )

Jenkins EC2  Architecture
---------------------------------

EC2 Instance
     ↓
Attached Dedicated EBS Volume
     ↓
Mounted to /data
     ↓
/data/jenkins
/data/sonarqube

Our project code has enured this .. 

what we have now

when we delete EC2 → deleted
Root Volume → deleted
Persistent EBS → survives

This becomes:

--------------------------------------
stateful persistence
+
disposable compute
--------------------------------------

COST IMPLICATIONS

Yes:
you WILL pay for:

root volume
dedicated EBS volume

because both are separate disks.

But:

root volume is temporary compute storage
dedicated EBS is business-critical persistence

This is normal enterprise practice.
--------------------------------------------------------------------------

setup.sh Block-by-Block Explanation
# setup.sh Block-by-Block Explanation

AWS Region Configuration
- Sets the default AWS region for AWS CLI commands.
- Ensures ECR, EKS, and AWS services communicate in the correct region.

System Update
- Updates system packages.
- Applies security patches and improves compatibility.

Docker Installation
- Installs Docker engine.
- Required for Jenkins, SonarQube, Docker builds, and Trivy scans.

Start and Enable Docker
- Starts Docker immediately.
- Ensures Docker starts automatically after EC2 reboot.

Docker Group Permissions
- Allows ec2-user to run Docker commands without sudo.
- Prevents permission issues.

AWS CLI Installation
- Installs AWS CLI v2 on the EC2 host.
- Required for ECR login, EKS authentication, and AWS automation.

Dedicated EBS Volume Mounting
- Detects and mounts persistent EBS storage.
- Separates compute from persistent application data.
- Allows Jenkins and SonarQube data to survive EC2 replacement.

Safe Filesystem Formatting
- Prevents formatting an already-used disk.
- Protects existing Jenkins and SonarQube data.

Mounting EBS to /data
- Makes persistent storage available to Jenkins and SonarQube.

Persisting Mount After Reboot
- Uses /etc/fstab so the EBS automatically remounts after reboot.

Persistent Directory Creation
- Creates Jenkins and SonarQube persistent storage directories.

Permission Fixing
- Aligns Linux permissions with container users (UID 1000).
- Prevents permission denied errors.

Docker Network Creation
- Allows Jenkins and SonarQube to communicate internally.

ECR Login
- Authenticates Docker with AWS ECR.

Pulling Immutable Jenkins Image
- Pulls prebuilt Jenkins image containing kubectl, Helm, AWS CLI, Docker CLI, and Node.js.
- Avoids repeated manual installations.

Removing Existing Containers
- Safely removes old containers before recreation.

Because your script is acting like:

deployment automation
immutable infrastructure

Meaning:

rebuild container cleanly each deployment
always use latest image
avoid stale containers

Jenkins Container Deployment
- Mounts persistent Jenkins storage into the container.

Docker Socket Mount
- Gives Jenkins access to Docker daemon on the EC2 host.
- Required for Docker builds and Trivy scans.

SonarQube Container Deployment
- Persists SonarQube database and logs.

Service Initialization Delay
- Gives Jenkins and SonarQube time to fully start before validation.

Health Checks
- Verifies Jenkins and SonarQube are actually responding.
- Containers may run while applications are unhealthy, so HTTP checks are important.

Tool Verification
- Confirms kubectl, Helm, Docker CLI, Node.js, and AWS CLI exist inside Jenkins image.

Jenkins Initial Password Retrieval
- Automatically retrieves the Jenkins admin password.which you can now get on the jenkins EC2 tobe able to log into your Jenkins UI

Final Output Information
- Displays URLs, credentials, webhook references, and storage paths.
----------------------------------------------------------------------------------


# Project Components Explained

# 1. GitHub

GitHub acts as the source code repository.

Every time code is pushed:

* Jenkins webhook gets triggered
* Jenkins pipeline starts automatically
* CI/CD process begins

We configured GitHub webhook using:

```text
http://<EC2-PUBLIC-IP>:8080/github-webhook/
```

---

# 2. Jenkins

Jenkins is the automation server.

It orchestrates:

* Build
* Testing
* Security scanning
* Docker image creation
* ECR push
* Kubernetes deployment

We containerized Jenkins using Docker.

---

# Why We Built a Custom Jenkins Image

Initially, Jenkins did not contain:

* kubectl
* Helm
* AWS CLI
* Docker CLI
* Node.js

Without these tools:

* Jenkins cannot communicate with EKS
* Jenkins cannot deploy with Helm
* Jenkins cannot build Docker images
* Jenkins cannot authenticate with AWS

So we baked these tools into a custom Jenkins image.

---

# Why Immutable Jenkins Images Matter

Instead of manually installing tools every time:

```text
kubectl
helm
awscli
trivy
nodejs
```

we embedded them into the Docker image.

This creates:

* consistency
* reproducibility
* portability
* easier recovery
* faster setup

Benefits:

If Jenkins container crashes:

* spin up new container
* same tools already exist
* same environment restored
* no manual setup needed

This is called immutable infrastructure.

---

# Jenkins Docker Image Contents

Our Jenkins image contains:

* Docker CLI
* AWS CLI
* kubectl
* Helm
* Node.js
* Git
* Curl
* Trivy support

This allows Jenkins to fully manage the deployment pipeline.

---

# Why We Installed kubectl and Helm Inside Jenkins Image

At first, kubectl was installed only on the EC2 host.

Problem:

The Jenkins container could not access kubectl.

This happens because:

```text
EC2 Host ≠ Docker Container
```

The container is isolated.

So even if kubectl exists on EC2:

* Jenkins container still cannot use it

Same issue happened with Helm.

---

# Correct Solution

Bake kubectl and Helm directly into the Jenkins image.

Benefits:

* Jenkins always has required tools
* portable environment
* reusable image
* no manual installation
* predictable deployments

---

# Why We Did NOT Bake Trivy Into Jenkins Image

We intentionally ran Trivy as a separate container:

```bash
 docker run --rm aquasec/trivy image my-app
```

instead of baking it into Jenkins image.

---

# Why This Is Better

If Trivy is baked into Jenkins image:

Problems:

* larger image size
* slower builds
* slower image pulls
* unnecessary dependencies
* harder maintenance

By running Trivy separately:

Benefits:

* smaller Jenkins image
* cleaner architecture
* easier upgrades
* independent versioning
* follows container best practices

This is closer to production-grade architecture.

---

# 3. Docker

Docker was used to:

* containerize Jenkins
* containerize the Node.js application
* isolate environments
* make deployments portable

---

# Why Docker Socket Was Mounted

We mounted:

```bash
-v /var/run/docker.sock:/var/run/docker.sock
```

into Jenkins container.

Reason:

Jenkins needed access to Docker daemon running on EC2 host.

Without this:

* Jenkins cannot build Docker images
* Jenkins cannot run Trivy container
* Jenkins cannot push images to ECR

---

# Docker-in-Docker vs Docker Socket Mount

We used:

```text
Docker Socket Mount
```

instead of:

```text
Docker-in-Docker
```

Why?

Docker socket mount:

Benefits:

* simpler
* faster
* lighter
* fewer permission issues
* common CI/CD pattern

---

# 4. Persistent Jenkins Storage

Initially we used:

```bash
-v jenkins_home:/var/jenkins_home
```

This created a Docker named volume.

Purpose:

Persist:

* Jenkins jobs
* plugins
* credentials
* pipeline configs
* build history

Without persistence:

Stopping container would wipe Jenkins state.

---

# Problem We Encountered

Later we switched to:

```bash
-v /data/jenkins:/var/jenkins_home
```

Problem:

Old jobs disappeared.

Reason:

The old Jenkins data still existed inside:

```text
Docker named volume
```

while new Jenkins container was pointing to:

```text
/data/jenkins
```

which was empty.

---

# Important Lesson

Changing persistence backend requires data migration.

We eventually restored jobs by reconnecting Jenkins to the original Docker volume.

---

# 5. AWS ECR

Amazon ECR stores Docker images.

Pipeline flow:

```text
Docker Build
     ↓
Tag Image
     ↓
Push to ECR
```

We used:

```bash
aws ecr get-login-password
```

for authentication.

---

# Image Tagging Strategy

Initially we used only:

```text
latest
```

Problem:

* difficult rollbacks
* difficult debugging
* unclear versions

Improved approach:

```text
v1
v2
v3
```

and:

```text
latest
```

This gives:

* rollback capability
* reproducibility
* traceability

---

# 6. SonarQube

SonarQube performs static code analysis.

Purpose:

* identify bugs
* detect vulnerabilities
* enforce code quality
* improve maintainability

Pipeline stage:

```text
Source Code
     ↓
SonarQube Scan
     ↓
Quality Gate
```

---

# Why Quality Gates Matter

Quality gate prevents deployment if:

* vulnerabilities exist
* code smells exceed threshold
* quality standards fail

This improves software quality before deployment.

---

# SonarQube Webhook Problem

When EC2 instance stopped and restarted:

* public IP changed
* SonarQube webhook broke

Reason:

Webhook still referenced old IP.

Fix:

Update:

```text
http://NEW-IP:8080/sonarqube-webhook/
```

---

# Better Long-Term Solution

Use:

* Elastic IP
  OR
* Domain Name

Benefits:

* stable URLs
* no webhook changes
* easier automation

---

# 7. Trivy Security Scanning

Trivy scans Docker images for:

* vulnerabilities
* CVEs
* insecure packages

Pipeline stage:

```text
Docker Build
     ↓
Trivy Scan
```

This introduces DevSecOps practices.

---

# Why Security Scanning Is Important

Without scanning:

* vulnerable packages may reach production
* insecure containers may deploy

Security should happen:

```text
before deployment
```

not after.

---

# 8. Kubernetes (EKS)

Amazon EKS hosts Kubernetes workloads.

Benefits:

* orchestration
* scaling
* self-healing
* rolling updates
* high availability

---

# Why We Used Helm

Helm simplifies Kubernetes deployments.

Instead of manually applying:

* Deployment YAML
* Service YAML
* ConfigMaps
* Secrets

Helm packages everything into reusable charts.

---

# Helm Chart Structure

```text
helm/
└── my-app/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

---

# Helm Problem We Encountered

Deployment kept failing with:

```text
Chart.yaml file is missing
```

Even though chart existed.

---

# Root Cause

File was named:

```text
chart.yaml
```

instead of:

```text
Chart.yaml
```

Helm REQUIRES:

```text
Chart.yaml
```

with capital C.

Linux is case-sensitive.

---

# Important Lesson

Many DevOps issues come from:

* path problems
* case sensitivity
* environment differences

Always verify:

* filenames
* paths
* runtime environment

---

# 9. Jenkins Pipeline Stages

# Checkout

Pull source code from GitHub.

---

# Build App

Install Node.js dependencies:

```bash
npm install
```

---

# SonarQube Scan

Analyze code quality.

---

# Quality Gate

Stop deployment if quality fails.

---

# Docker Build

Build application container.

---

# Trivy Scan

Perform container security scanning.

---

# Push to ECR

Store image in AWS container registry.

---

# Deploy to EKS

Deploy application to Kubernetes using Helm.

---

# Docker Cleanup

Remove unused Docker artifacts.

---

# Cleanup Trade-Offs

Initially we used:

```bash
docker system prune -af
```

Problem:

Too aggressive.

It removed:

* old images
* build cache
* Trivy image
* Jenkins image layers

Better alternative:

```bash
docker image prune -af
```

Safer cleanup strategy.

---

# 10. Setup Automation

We automated EC2 bootstrap using:

```text
setup.sh
```

Purpose:

Automatically install:

* Docker
* AWS CLI
* kubectl
* networking
* Docker volumes
* Jenkins container
* SonarQube container

This creates reusable infrastructure.

---

# Why Automation Matters

Without automation:

* manual errors increase
* setup becomes inconsistent
* recovery becomes difficult

Automation creates:

* repeatability
* speed
* reliability

---

# 11. AWS_PAGER Issue

AWS CLI initially failed with:

```text
Unable to redirect output to pager
```

Reason:

Minimal containers lacked:

```text
less
```

Fix:

```Dockerfile
ENV AWS_PAGER=""
```

This disabled pager usage.

---

# Important Lesson

Containers are minimal environments.

Never assume:

* shell tools exist
* editors exist
* pagers exist

Always explicitly configure CI/CD environments.

---

# 12. Docker Permissions Problem

Jenkins initially failed accessing Docker.

Reason:

Container user lacked:

```text
docker group access
```

Fix:

```Dockerfile
usermod -aG docker jenkins
```

and mounting:

```bash
/var/run/docker.sock
```

---

# 13. Jenkins Permission Problem

We encountered:

```text
missing rw permissions on JENKINS_HOME
```

Reason:

Host directory ownership mismatch.

Fix:

```bash
sudo chown -R 1000:1000 /data/jenkins
```

This aligned host permissions with Jenkins container user.

---

# 14. Why We Used EKS Instead of EC2 Deployments

Traditional EC2 deployments:

Problems:

* manual scaling
* downtime risks
* harder orchestration
* poor resilience

Kubernetes provides:

* self-healing
* rolling deployments
* scaling
* declarative infrastructure
* better production readiness

---

# 15. Final Lessons Learned

# Infrastructure Should Be Immutable

Bake dependencies into images.

---

# Persistence Matters

Without persistence:

* CI/CD state disappears

---

# Containers Are Isolated

Host tools are not automatically available inside containers.

---

# DevSecOps Matters

Security scanning should happen before deployment.

---

# Automation Is Critical

Everything repeatable should be automated.

---

# Kubernetes Requires Proper Tooling

kubectl + Helm + AWS auth must all work together.

---

# Small Details Matter

Case sensitivity caused deployment failure.

---

# Final Working Stack

```text
GitHub
Jenkins
Docker
SonarQube
Trivy
Amazon ECR
Amazon EKS
Helm
Terraform
AWS EC2
Kubernetes
```

---

# How To Access The Application In Browser

First check Kubernetes service:

```bash
kubectl get svc
```

If service type is:

```text
LoadBalancer
```

wait a few minutes and run:

```bash
kubectl get svc
```

again.

You should eventually see:

```text
EXTERNAL-IP
```

Example:

```text
a1b2c3d4.us-east-1.elb.amazonaws.com
```

Open in browser:

```text
http://EXTERNAL-IP
```

---

# If External IP Is Pending

Possible reasons:

* AWS Load Balancer provisioning delay
* Service type not LoadBalancer
* IAM permissions issue

---

# Useful Kubernetes Commands

View pods:

```bash
kubectl get pods
```

View services:

```bash
kubectl get svc
```

View deployments:

```bash
kubectl get deployments
```

View Helm releases:

```bash
helm list -A
```

Describe pod:

```bash
kubectl describe pod <pod-name>
```

View logs:

```bash
kubectl logs <pod-name>
```

---

# Conclusion

This project demonstrates a real-world DevOps workflow involving:

* CI/CD
* Infrastructure Automation
* Containerization
* Security Scanning
* Kubernetes Deployments
* Immutable Infrastructure
* Cloud-Native Engineering

The most important part was not just getting the application deployed.

The most important part was understanding:

* WHY each tool exists
* HOW they interact
* WHAT problems they solve
* WHAT trade-offs exist
* HOW to debug failures

That understanding is what transforms someone from:

```text
Tool user
```

into:

```text
Cloud/DevOps Engineer
```

# Accessing the Application Online

After the Helm deployment successfully completes, Kubernetes creates a Service for the application.

To verify the service:

```bash
kubectl get svc

NAME             TYPE           CLUSTER-IP       EXTERNAL-IP                                                                 PORT(S)
my-app-service   LoadBalancer   172.20.113.56   a3963c5bc03a84ebca5d21ed0fbc9709-683679299.us-east-1.elb.amazonaws.com   80:30420/TCP

Understanding the Output
LoadBalancer:
Kubernetes automatically provisions an AWS Elastic Load Balancer (ELB).
EXTERNAL-IP:
This is the public DNS endpoint created by AWS.
80:30420/TCP:
80 = public port exposed to the internet
30420 = internal Kubernetes NodePort

Because the service type is LoadBalancer, users only need the ELB DNS name to access the application.


Accessing the Application in Browser

Open the browser and visit:

http://a3963c5bc03a84ebca5d21ed0fbc9709-683679299.us-east-1.elb.amazonaws.com

No additional port is required because AWS Load Balancer forwards traffic from port 80 automatically to the Kubernetes service.

Browser
   ↓
AWS Elastic Load Balancer
   ↓
Kubernetes Service (LoadBalancer)
   ↓
Kubernetes Pods
   ↓
Node.js Application

Benefits:

Public internet access
Automatic AWS Load Balancer provisioning
Traffic distribution across pods
Easier production exposure
Native AWS integration

Important Notes
The LoadBalancer DNS may take 2–5 minutes to become active after deployment.
Every new deployment reuses the same service unless deleted.
If the service is deleted and recreated, AWS may provision a new DNS endpoint.

BETTER PRACTICE BEFORE DESTROY

Before:

terraform destroy

you should FIRST delete Kubernetes services manually:

kubectl delete svc my-app-service

OR BETTER STILL  

kubectl delete svc --all

Then wait a few minutes.

Then run:

terraform destroy