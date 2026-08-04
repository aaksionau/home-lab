#!/usr/bin/env bash
# One-shot upgrade for the stocks-research containers: builds + pushes new
# images, then applies terraform/03-stocks-platform with the new tag(s).
#
# Meant to be run directly on the Ubuntu server (terraform/03-stocks-platform
# reads 01-infrastructure's state via a local relative path, so terraform
# apply has to happen here, not from a separate dev machine).
#
# Usage (run from this repo's scripts/ dir on the server):
#   ./upgrade-stocks.sh [tag] [-y|--auto-approve]
#
# [tag] defaults to the short git SHA of STOCKS_REPO's current HEAD. Note
# this means re-running against the same commit produces the same tag, which
# won't trigger a rollout (see README) -- commit first, or pass an explicit
# tag, if you want to force a fresh deploy.
# -y/--auto-approve skips terraform's interactive confirmation prompt.
#
# Optional env var:
#   STOCKS_REPO   Path to the stocks-research checkout to build from.
#                 Defaults to the sibling directory of this repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STOCKS_REPO="${STOCKS_REPO:-$(cd "${SCRIPT_DIR}/../../stocks-research" && pwd)}"

AUTO_APPROVE=""
TAG=""
for arg in "$@"; do
  case "$arg" in
    -y|--auto-approve) AUTO_APPROVE="-auto-approve" ;;
    *) TAG="$arg" ;;
  esac
done
TAG="${TAG:-$(git -C "${STOCKS_REPO}" rev-parse --short HEAD)}"

echo "==> Reading registry_host from 01-infrastructure state"
REGISTRY_HOST="$(terraform -chdir="${HOME_SERVER_DIR}/terraform/01-infrastructure" output -raw registry_host)"
echo "    registry_host=${REGISTRY_HOST}"

echo "==> Building and pushing stocks-pipeline / stocks-web at tag ${TAG}"
REGISTRY_HOST="${REGISTRY_HOST}" STOCKS_REPO="${STOCKS_REPO}" \
  "${SCRIPT_DIR}/build-and-push-stocks.sh" "${TAG}"

echo "==> Applying terraform/03-stocks-platform with pipeline_image_tag=web_image_tag=${TAG}"
terraform -chdir="${HOME_SERVER_DIR}/terraform/03-stocks-platform" apply \
  -var="pipeline_image_tag=${TAG}" -var="web_image_tag=${TAG}" ${AUTO_APPROVE}

echo "Done. stocks-pipeline and stocks-web are now on tag ${TAG}."
