#!/usr/bin/env bash
# One-shot upgrade for the stocks-research containers: builds + pushes new
# images, then applies terraform/03-stocks-platform on the server with the
# new tag(s).
#
# Terraform for 02/03-platform reads 01-infrastructure's state via a local
# relative path (remote_state.tf), so it must run on the Ubuntu server
# itself -- this script builds/pushes locally (wherever Docker can reach the
# registry) and then SSHes in to run `terraform apply`.
#
# Usage:
#   SERVER_SSH=user@192.168.1.50 REMOTE_HOME_SERVER_PATH=~/home-server \
#     ./upgrade-stocks.sh [tag] [-y|--auto-approve]
#
# [tag] defaults to the short git SHA of STOCKS_REPO's current HEAD.
# -y/--auto-approve skips terraform's interactive confirmation prompt.
#
# Required env vars (set them in your shell profile so you don't retype
# them every time):
#   SERVER_SSH               SSH target for the Ubuntu server, e.g. alexe@192.168.1.50
#   REMOTE_HOME_SERVER_PATH  Path to the home-server checkout on that server, e.g. ~/home-server
#
# Optional:
#   STOCKS_REPO   Path to the stocks-research checkout to build from.
#                 Defaults to the sibling directory of this repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER_SSH="${SERVER_SSH:?set SERVER_SSH, e.g. alexe@192.168.1.50}"
REMOTE_HOME_SERVER_PATH="${REMOTE_HOME_SERVER_PATH:?set REMOTE_HOME_SERVER_PATH, e.g. ~/home-server}"
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

echo "==> Fetching registry_host from the server's 01-infrastructure state"
REGISTRY_HOST="$(ssh "${SERVER_SSH}" \
  "terraform -chdir=${REMOTE_HOME_SERVER_PATH}/terraform/01-infrastructure output -raw registry_host")"
echo "    registry_host=${REGISTRY_HOST}"

echo "==> Building and pushing stocks-pipeline / stocks-web at tag ${TAG}"
REGISTRY_HOST="${REGISTRY_HOST}" STOCKS_REPO="${STOCKS_REPO}" \
  "${SCRIPT_DIR}/build-and-push-stocks.sh" "${TAG}"

echo "==> Applying terraform/03-stocks-platform on ${SERVER_SSH} with pipeline_image_tag=web_image_tag=${TAG}"
ssh -t "${SERVER_SSH}" \
  "terraform -chdir=${REMOTE_HOME_SERVER_PATH}/terraform/03-stocks-platform apply \
    -var='pipeline_image_tag=${TAG}' -var='web_image_tag=${TAG}' ${AUTO_APPROVE}"

echo "Done. stocks-pipeline and stocks-web are now on tag ${TAG}."
