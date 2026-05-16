STEP 1 — Check disk usage

Run on EC2:

df -h
🧪 STEP 2 — Check Docker usage
docker system df
🚀 STEP 3 — CLEAN UP SPACE (SAFE)

Run these:

🔥 Remove unused containers
docker container prune -f
🔥 Remove unused images
docker image prune -a -f
🔥 Remove unused volumes (be careful but safe here)
docker volume prune -f
🔥 Remove build cache
docker builder prune -a -f
🚀 STEP 4 — Clean Linux packages

sudo yum clean all
sudo rm -rf /var/cache/yum
🚀 STEP 5 — Clean Jenkins workspace (VERY EFFECTIVE)
sudo rm -rf /var/lib/docker/volumes/jenkins_home/_data/workspace/*

👉 Jenkins will re-clone automatically

MPORTANT

This does NOT delete:

✔ Jenkins jobs
✔ credentials
✔ configs
🚀 AFTER CLEANUP

Restart Jenkins:

docker restart jenkins
🔥 THEN FIX YOUR PIPELINE (IMPORTANT)

Now that disk is fixed, go back to the correct approach:

Build stage (FINAL VERSION)
stage('Build App') {
  steps {
    dir('app') {
      sh 'npm install'
    }
  }
}

👉 DO NOT use Docker for npm anymore