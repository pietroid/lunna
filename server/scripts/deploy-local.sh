#!/usr/bin/env bash
set -euo pipefail

# deploy-local.sh
#
# Deploy the NestJS backend locally on the Raspberry Pi by building the Docker
# images directly on the Pi.
#
# Usage:
#   scripts/deploy-local.sh
#
# Must be run from inside the Raspberry Pi where the repo is cloned.
# It pulls the latest code, builds the Docker images natively, and starts
# the containers with docker compose.
#
# The service account JSON key must already be present on the Pi at:
#   /opt/focus/secrets/focus-backend-prod.json
# The key is NEVER committed; keep it outside version control.
#
# The Flutter web app is served separately by the focus-web (nginx) container.
# Populate /opt/focus/web on the Pi by running app/scripts/deploy-web.sh from
# your development machine, or by using the GitHub Actions deploy-app workflow.
#
# Note: this script builds images locally on the Pi. For faster deploys from
# GitHub Actions, see .github/workflows/deploy-server.yml and
# .github/workflows/deploy-agent.yml, which build multi-arch images and push
# them to GitHub Container Registry (ghcr.io).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$ROOT_DIR/.env.production"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
BACKEND_IMAGE="focus-backend:latest"
AGENT_DIR="$ROOT_DIR/../agent"
AGENT_IMAGE="focus-agent:latest"

# Tell docker compose to use the locally-built image names. GitHub Actions
# overrides these variables to use the ghcr.io registry images instead.
export FOCUS_BACKEND_IMAGE="$BACKEND_IMAGE"
export FOCUS_AGENT_IMAGE="$AGENT_IMAGE"

cd "$ROOT_DIR"

echo "Pulling latest code..."
git pull

echo ""
echo "Ensuring web root exists..."
mkdir -p /opt/focus/web

echo ""
echo "Building backend Docker image..."
docker build -t "$BACKEND_IMAGE" .

echo ""
echo "Building agent Docker image..."
docker build -t "$AGENT_IMAGE" "$AGENT_DIR"

echo ""
echo "Starting containers with docker compose..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

echo ""
echo "Deployment complete."
echo ""
echo "Make sure the service account key is present on the Pi at:"
echo "  /opt/focus/secrets/focus-backend-prod.json"
echo ""
echo "Make sure the agent environment file is present on the Pi at:"
echo "  $AGENT_DIR/.env.production"
