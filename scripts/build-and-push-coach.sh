#!/usr/bin/env bash
# Builds the coach images (coach-web + coach-garmin-ingestion) and pushes them to
# the insecure registry provisioned by terraform/01-infrastructure (registry.tf),
# running on the Ubuntu server at ${REGISTRY_HOST}.
#
# Usage:
#   REGISTRY_HOST=192.168.1.50:5000 COACH_REPO=/path/to/personal-coach ./build-and-push-coach.sh [tag]
#
# Requires Docker configured to treat REGISTRY_HOST as an insecure registry
# (add it to /etc/docker/daemon.json -> "insecure-registries" and restart
# Docker on the machine running this script, if pushing from somewhere other
# than the server itself).

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:?set REGISTRY_HOST, e.g. 192.168.1.50:5000}"
COACH_REPO="${COACH_REPO:?set COACH_REPO to the personal-coach checkout path}"
TAG="${1:-latest}"

# Both Dockerfiles use the repo root as the build context -- they reference
# sibling projects under src/.
web_image="${REGISTRY_HOST}/coach/coach-web:${TAG}"
garmin_image="${REGISTRY_HOST}/coach/coach-garmin-ingestion:${TAG}"

echo "==> Building ${web_image}"
docker build -f "${COACH_REPO}/src/Coach.Web/Dockerfile" -t "${web_image}" "${COACH_REPO}"

echo "==> Building ${garmin_image}"
docker build -f "${COACH_REPO}/src/Coach.GarminIngestion/Dockerfile" -t "${garmin_image}" "${COACH_REPO}"

echo "==> Pushing ${web_image}"
docker push "${web_image}"

echo "==> Pushing ${garmin_image}"
docker push "${garmin_image}"

echo "Done. Set web_image_tag = \"${TAG}\" and garmin_ingestion_image_tag = \"${TAG}\" in terraform/04-coach-platform/terraform.tfvars and re-apply."
