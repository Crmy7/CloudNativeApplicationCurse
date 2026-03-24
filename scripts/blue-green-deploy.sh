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

# Arreter l'ancien stack (TP4) s'il tourne encore
echo ">> Nettoyage de l'ancien stack..."
docker compose -f docker-compose.yml down 2>/dev/null || true

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

# S'assurer que active.conf pointe vers la couleur inactive AVANT de demarrer le proxy
# Cela evite que Nginx crashe parce que l'upstream active n'existe pas encore
echo ">> Configuration du proxy vers $INACTIVE..."
cp "nginx/$INACTIVE.conf" nginx/active.conf

# Demarrer postgres (sans le proxy pour l'instant)
echo ">> Demarrage de PostgreSQL..."
COMPOSE_PROJECT_NAME=$PROJECT docker compose -f $BASE_FILE up -d postgres

# Attendre que postgres soit healthy
echo ">> Attente de PostgreSQL..."
for i in $(seq 1 30); do
  if docker exec cloudnative-postgres pg_isready -U postgres 2>/dev/null; then
    echo ">> PostgreSQL est pret."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERREUR: PostgreSQL n'est pas pret apres 60s"
    exit 1
  fi
  sleep 2
done

# Deployer la version inactive
echo ">> Deploiement de la version $INACTIVE..."
COMPOSE_PROJECT_NAME=$PROJECT DEPLOY_TAG="$TAG" docker compose -f $BASE_FILE -f "docker-compose.$INACTIVE.yml" up -d

# Attendre que les services soient prets
echo ">> Attente du demarrage des services $INACTIVE..."
sleep 15

# Demarrer/redemarrer le proxy maintenant que les backends existent
echo ">> Demarrage du reverse proxy..."
COMPOSE_PROJECT_NAME=$PROJECT docker compose -f $BASE_FILE up -d reverse-proxy
sleep 3

# Forcer le reload de la config
docker exec cloudnative-proxy nginx -s reload 2>/dev/null || true
sleep 2

# Verification via le proxy
echo ">> Verification via le proxy..."
curl -f http://localhost/health || { echo "ERREUR: health check via proxy echoue"; exit 1; }

echo ""
echo "=== Deploiement Blue/Green termine ==="
echo ">> Version active : $INACTIVE"
echo ">> Ancienne version ($ACTIVE) toujours disponible pour rollback"
echo ""
echo ">> Pour rollback : cp nginx/$ACTIVE.conf nginx/active.conf && docker exec cloudnative-proxy nginx -s reload"
