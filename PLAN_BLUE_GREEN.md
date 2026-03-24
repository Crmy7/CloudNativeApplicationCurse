# Plan de deploiement Blue/Green

## Strategie

Le deploiement blue/green permet de maintenir deux versions de l'application en parallele.
Un reverse proxy Nginx route le trafic vers la version active (blue ou green).
La bascule se fait en modifiant un fichier de configuration Nginx et en rechargeant le proxy, sans downtime.

## Architecture

```
[Client] --> :80 [Nginx Reverse Proxy] --> [Blue]   (version active)
                                       \-> [Green]  (version candidate)

             [PostgreSQL] <--- shared by both blue and green
```

## Fichiers Docker Compose

| Fichier                    | Contenu                                      |
| -------------------------- | -------------------------------------------- |
| `docker-compose.base.yml`  | PostgreSQL + Nginx reverse proxy              |
| `docker-compose.blue.yml`  | backend-blue + frontend-blue                  |
| `docker-compose.green.yml` | backend-green + frontend-green                |

La separation permet de deployer une couleur sans toucher l'autre.

## Comment l'ensemble est lance

```bash
# Demarrer l'infra + blue
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d

# Deployer green sans toucher blue
docker compose -f docker-compose.base.yml -f docker-compose.green.yml up -d

# Basculer le proxy vers green
cp nginx/green.conf nginx/active.conf
docker compose -f docker-compose.base.yml exec reverse-proxy nginx -s reload
```

## Bascule du proxy

La bascule s'opere via un fichier `nginx/active.conf` monte dans le conteneur Nginx.

- `nginx/blue.conf` : route vers backend-blue:3000 et frontend-blue:80
- `nginx/green.conf` : route vers backend-green:3000 et frontend-green:80
- `nginx/active.conf` : copie du fichier de la couleur active

Lors d'un deploiement, le script :
1. Copie le fichier de la nouvelle couleur dans `active.conf`
2. Recharge Nginx avec `nginx -s reload` (zero downtime)

## Scenario de deploiement

### Etat initial
- **Blue** est en production (active)
- `nginx/active.conf` pointe vers blue

### Nouveau deploiement
1. Le pipeline lit la couleur active depuis `nginx/active.conf`
2. Il determine la couleur inactive (si blue est active -> deployer sur green)
3. Il pull les nouvelles images et les tag pour la couleur inactive
4. Il lance `docker compose -f docker-compose.base.yml -f docker-compose.<inactive>.yml up -d`
5. Il attend que les services soient healthy
6. Il copie `nginx/<inactive>.conf` vers `nginx/active.conf`
7. Il recharge Nginx : `docker compose -f docker-compose.base.yml exec reverse-proxy nginx -s reload`

### Rollback
1. Copier `nginx/<ancienne_couleur>.conf` vers `nginx/active.conf`
2. Recharger Nginx : `nginx -s reload`
3. L'ancienne version est immediatement de retour (les conteneurs tournent toujours)

Le rollback prend moins de 2 secondes car il suffit de recharger la config Nginx.

## Stockage de la couleur active

La couleur active est determinee en inspectant le contenu de `nginx/active.conf` :
- Si le fichier contient `backend-blue` -> blue est active
- Si le fichier contient `backend-green` -> green est active

Aucun fichier d'etat externe n'est necessaire.
