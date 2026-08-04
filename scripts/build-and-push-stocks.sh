#!/usr/bin/env bash
# Builds the 3 stocks-research images (pipeline + news-pipeline + web) and pushes them to
# the insecure registry provisioned by terraform/01-infrastructure
# (registry.tf), running on the Ubuntu server at ${REGISTRY_HOST}.
#
# Usage:
#   REGISTRY_HOST=192.168.1.50:5000 STOCKS_REPO=/path/to/stocks-research ./build-and-push-stocks.sh [tag]
#
# Requires Docker configured to treat REGISTRY_HOST as an insecure registry
# (add it to /etc/docker/daemon.json -> "insecure-registries" and restart
# Docker on the machine running this script, if pushing from somewhere other
# than the server itself).

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:?set REGISTRY_HOST, e.g. 192.168.1.50:5000}"
STOCKS_REPO="${STOCKS_REPO:?set STOCKS_REPO to the stocks-research checkout path}"
TAG="${1:-latest}"

declare -A SERVICES=(
  [stocks-pipeline]="docker/pipeline.Dockerfile"
  [stocks-news-pipeline]="docker/news-pipeline.Dockerfile"
  [stocks-web]="docker/web.Dockerfile"
)

for name in "${!SERVICES[@]}"; do
  dockerfile="${STOCKS_REPO}/${SERVICES[$name]}"
  image="${REGISTRY_HOST}/stocks/${name}:${TAG}"

  echo "==> Building ${image} from ${dockerfile}"
  docker build -f "${dockerfile}" -t "${image}" "${STOCKS_REPO}"

  echo "==> Pushing ${image}"
  docker push "${image}"
done

echo "Done. Set pipeline_image_tag/news_pipeline_image_tag/web_image_tag = \"${TAG}\" in terraform/03-stocks-platform/terraform.tfvars and re-apply."
