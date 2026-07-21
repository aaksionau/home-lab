# A self-hosted GitHub Actions runner for weather-home-station, living on
# the Ubuntu host so it can reach the registry over localhost (see the
# REGISTRY_HOST trick in .github/workflows/build-and-push.yml) without any
# LAN exposure. It only builds and pushes images — it never touches the
# cluster or runs `terraform apply`; deploys stay a manual step.
#
# Caution: it's given the host's Docker socket so it can run `docker build`/
# `docker push` itself. That's equivalent to root on the host — acceptable
# for a single-user homelab reachable only by you, not something to expose
# further.

resource "docker_image" "ci_runner" {
  name = "myoung34/github-runner:latest"
}

resource "docker_container" "ci_runner" {
  name  = "weather-ci-runner"
  image = docker_image.ci_runner.image_id

  restart = "unless-stopped"

  env = [
    "REPO_URL=${var.github_repo_url}",
    "ACCESS_TOKEN=${var.github_runner_pat}",
    "RUNNER_NAME=weather-ci-runner",
    "RUNNER_WORKDIR=/tmp/runner/work",
    "LABELS=self-hosted,weather-ci",
    "RUNNER_SCOPE=repo",
    "DOCKER_ENABLED=true",
  ]

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
}
