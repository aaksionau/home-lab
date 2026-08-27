#!/usr/bin/env bash
# One-shot upgrade for coach-web: builds + pushes a new image, then applies
# terraform/04-coach-platform with the new tag.
#
# Meant to be run directly on the Ubuntu server (terraform/04-coach-platform
# reads 01-infrastructure's state via a local relative path, so terraform
# apply has to happen here, not from a separate dev machine).
#
# Usage (run from this repo's scripts/ dir on the server):
#   ./upgrade-coach.sh [tag] [-y|--auto-approve]
#
# [tag] defaults to the short git SHA of COACH_REPO's current HEAD. Note
# this means re-running against the same commit produces the same tag, which
# won't trigger a rollout (see README) -- commit first, or pass an explicit
# tag, if you want to force a fresh deploy.
# -y/--auto-approve skips terraform's interactive confirmation prompt.
#
# Optional env var:
#   COACH_REPO   Path to the personal-coach checkout to build from.
#                Defaults to the sibling directory of this repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COACH_REPO="${COACH_REPO:-$(cd "${SCRIPT_DIR}/../../personal-coach" && pwd)}"

AUTO_APPROVE=""
TAG=""
for arg in "$@"; do
  case "$arg" in
    -y|--auto-approve) AUTO_APPROVE="-auto-approve" ;;
    *) TAG="$arg" ;;
  esac
done
TAG="${TAG:-$(git -C "${COACH_REPO}" rev-parse --short HEAD)}"

echo "==> Reading registry_host from 01-infrastructure state"
REGISTRY_HOST="$(terraform -chdir="${HOME_SERVER_DIR}/terraform/01-infrastructure" output -raw registry_host)"
echo "    registry_host=${REGISTRY_HOST}"

echo "==> Building and pushing coach images at tag ${TAG}"
REGISTRY_HOST="${REGISTRY_HOST}" COACH_REPO="${COACH_REPO}" \
  "${SCRIPT_DIR}/build-and-push-coach.sh" "${TAG}"

echo "==> Applying terraform/04-coach-platform with image tags=${TAG}"
terraform -chdir="${HOME_SERVER_DIR}/terraform/04-coach-platform" apply \
  -var="web_image_tag=${TAG}" \
  -var="garmin_ingestion_image_tag=${TAG}" ${AUTO_APPROVE}

echo "Done. coach-web and coach-garmin-ingestion are now on tag ${TAG}."
