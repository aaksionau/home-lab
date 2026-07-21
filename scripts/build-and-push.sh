#!/usr/bin/env bash
# Builds the 5 weather-station service images and pushes them to the
# insecure registry provisioned by terraform/01-infrastructure (registry.tf),
# running on the Ubuntu server at ${REGISTRY_HOST}.
#
# Usage:
#   REGISTRY_HOST=192.168.1.50:5000 WEATHER_REPO=/path/to/weather-home-station ./build-and-push.sh [tag]
#
# Requires Docker configured to treat REGISTRY_HOST as an insecure registry
# (add it to /etc/docker/daemon.json -> "insecure-registries" and restart
# Docker on the machine running this script, if pushing from somewhere other
# than the server itself).

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:?set REGISTRY_HOST, e.g. 192.168.1.50:5000}"
WEATHER_REPO="${WEATHER_REPO:?set WEATHER_REPO to the weather-home-station checkout path}"
TAG="${1:-latest}"

declare -A SERVICES=(
  [weather-gateway-api]="src/WeatherGateway.API"
  [weather-processor-worker]="src/WeatherProcessor.Worker"
  [weather-rules-worker]="src/WeatherRules.Worker"
  [dashboard-api]="src/Dashboard.API"
  [dashboard-web]="src/Dashboard.Web"
)

for name in "${!SERVICES[@]}"; do
  context="${WEATHER_REPO}/${SERVICES[$name]}"
  image="${REGISTRY_HOST}/weather/${name}:${TAG}"

  echo "==> Building ${image} from ${context}"
  docker build -t "${image}" "${context}"

  echo "==> Pushing ${image}"
  docker push "${image}"
done

echo "Done. Set image_tag = \"${TAG}\" in terraform/02-platform/terraform.tfvars and re-apply."
