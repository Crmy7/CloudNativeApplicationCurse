#!/bin/bash
set -e

REGISTRY="ghcr.io/crmy7"
TAG="${GITHUB_SHA:-latest}"

echo "=== Deploiement automatique ==="
echo "Tag: $TAG"

echo ">> Arret des conteneurs en cours..."
docker compose down

echo ">> Pull des nouvelles images..."
docker pull "$REGISTRY/cloudnative-backend:$TAG"
docker pull "$REGISTRY/cloudnative-frontend:$TAG"

echo ">> Tag des images pour docker compose..."
docker tag "$REGISTRY/cloudnative-backend:$TAG" cloudnative-backend:latest
docker tag "$REGISTRY/cloudnative-frontend:$TAG" cloudnative-frontend:latest

echo ">> Demarrage de l'environnement..."
docker compose up -d

echo ">> Attente du demarrage des services..."
sleep 10

echo ">> Verification de sante..."
curl -f http://localhost/health || { echo "ERREUR: health check echoue"; exit 1; }

echo ""
echo "=== Deploiement termine avec succes ==="
docker compose ps
