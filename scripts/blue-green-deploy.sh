#!/bin/bash
set -e

REGISTRY="ghcr.io/crmy7"
TAG="${GITHUB_SHA:-latest}"
PROJECT="cloudnative"
BASE_FILE="docker-compose.base.yml"

echo "=== Deploiement Blue/Green ==="
echo "Tag: $TAG"

# Creer le .env s'il n'existe pas
if [ ! -f .env ]; then
  echo ">> Creation du fichier .env depuis .env.example..."
  cp .env.example .env
fi

# Determiner la couleur active
if grep -q "backend-blue" nginx/active.conf 2>/dev/null; then
  ACTIVE="blue"
  INACTIVE="green"
else
  ACTIVE="green"
  INACTIVE="blue"
fi

echo ">> Couleur active : $ACTIVE"
echo ">> Deploiement sur : $INACTIVE"

# Pull des nouvelles images
echo ">> Pull des nouvelles images..."
docker pull "$REGISTRY/cloudnative-backend:$TAG"
docker pull "$REGISTRY/cloudnative-frontend:$TAG"

# Tag pour la couleur inactive
echo ">> Tag des images pour $INACTIVE..."
docker tag "$REGISTRY/cloudnative-backend:$TAG" "ghcr.io/crmy7/cloudnative-backend:$INACTIVE"
docker tag "$REGISTRY/cloudnative-frontend:$TAG" "ghcr.io/crmy7/cloudnative-frontend:$INACTIVE"

# Demarrer l'infra de base si pas deja up
echo ">> Demarrage de l'infra de base (postgres + proxy)..."
COMPOSE_PROJECT_NAME=$PROJECT docker compose -f $BASE_FILE up -d

# Attendre que postgres soit healthy
echo ">> Attente de PostgreSQL..."
until docker compose -f $BASE_FILE exec -T postgres pg_isready -U postgres 2>/dev/null; do
  sleep 2
done

# Deployer la version inactive
echo ">> Deploiement de la version $INACTIVE..."
COMPOSE_PROJECT_NAME=$PROJECT DEPLOY_TAG="$TAG" docker compose -f $BASE_FILE -f "docker-compose.$INACTIVE.yml" up -d

# Attendre que les services soient prets
echo ">> Attente du demarrage des services $INACTIVE..."
sleep 15

# Verifier que la nouvelle version repond
echo ">> Verification de la version $INACTIVE..."
docker compose -f $BASE_FILE -f "docker-compose.$INACTIVE.yml" exec -T "backend-$INACTIVE" wget -qO- http://localhost:3000/health || {
  echo "ERREUR: La version $INACTIVE ne repond pas. Annulation."
  exit 1
}

# Basculer le proxy
echo ">> Bascule du proxy vers $INACTIVE..."
cp "nginx/$INACTIVE.conf" nginx/active.conf
COMPOSE_PROJECT_NAME=$PROJECT docker compose -f $BASE_FILE exec -T reverse-proxy nginx -s reload

echo ">> Verification via le proxy..."
sleep 3
curl -f http://localhost/health || { echo "ERREUR: health check via proxy echoue"; exit 1; }

echo ""
echo "=== Deploiement Blue/Green termine ==="
echo ">> Version active : $INACTIVE"
echo ">> Ancienne version ($ACTIVE) toujours disponible pour rollback"
echo ""
echo ">> Pour rollback : cp nginx/$ACTIVE.conf nginx/active.conf && docker compose -f $BASE_FILE exec reverse-proxy nginx -s reload"
echo ""
docker compose -f $BASE_FILE -f "docker-compose.$INACTIVE.yml" ps
