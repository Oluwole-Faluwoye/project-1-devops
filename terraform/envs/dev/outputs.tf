output "jenkins_ip" {
  value = module.jenkins.public_ip
}

output "app_ecr_repo" {
  value = module.app_ecr.repository_url
}