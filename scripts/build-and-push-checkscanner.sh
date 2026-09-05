#!/usr/bin/env bash
# Builds the checkscanner-web image and pushes it to the insecure registry
# provisioned by terraform/01-infrastructure (registry.tf), running on the
# Ubuntu server at ${REGISTRY_HOST}.
#
# Usage:
#   REGISTRY_HOST=192.168.1.50:5000 CHECKSCANNER_REPO=/path/to/check-scanner ./build-and-push-checkscanner.sh [tag]
#
# Requires Docker configured to treat REGISTRY_HOST as an insecure registry
# (add it to /etc/docker/daemon.json -> "insecure-registries" and restart
# Docker on the machine running this script, if pushing from somewhere other
# than the server itself).

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:?set REGISTRY_HOST, e.g. 192.168.1.50:5000}"
CHECKSCANNER_REPO="${CHECKSCANNER_REPO:?set CHECKSCANNER_REPO to the check-scanner checkout path}"
TAG="${1:-latest}"

# The Dockerfile uses the repo root as the build context -- it references
# sibling projects under src/.
web_image="${REGISTRY_HOST}/groceries/checkscanner-web:${TAG}"

echo "==> Building ${web_image}"
docker build -f "${CHECKSCANNER_REPO}/src/CheckScanner.Web/Dockerfile" -t "${web_image}" "${CHECKSCANNER_REPO}"

echo "==> Pushing ${web_image}"
docker push "${web_image}"

echo "Done. Set web_image_tag = \"${TAG}\" in terraform/05-groceries-platform/terraform.tfvars and re-apply."
