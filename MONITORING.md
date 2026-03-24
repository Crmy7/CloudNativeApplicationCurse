# Monitoring & Observabilite (TP6)

## Composants de la stack

| Composant    | Role                                                         | Port  |
| ------------ | ------------------------------------------------------------ | ----- |
| **Prometheus** | Scraping et stockage de metriques time-series               | 9090  |
| **Grafana**    | Visualisation, dashboards, alerting                         | 3000  |
| **Loki**       | Stockage et indexation des logs (comme Prometheus pour les logs) | 3100  |
| **Promtail**   | Agent de collecte des logs Docker, envoi vers Loki          | 9080  |

---

## Architecture

```
                        +------------------+
                        |     Grafana      |  :3000
                        |  (visualisation) |
                        +--------+---------+
                                 |
                    +------------+------------+
                    |                         |
             +------+------+          +------+------+
             |  Prometheus |          |    Loki     |
             |  (metriques)|          |   (logs)    |
             +------+------+          +------+------+
                    |                         |
              scrape /metrics          push logs
                    |                         |
         +----------+----------+       +------+------+
         |   Backend (Express) |       |  Promtail   |
         |   /metrics endpoint |       | (collecteur)|
         +---------------------+       +------+------+
                                              |
                                     Docker socket
                                     (stdout logs)
```

---

## Les 3 piliers de l'observabilite

| Pilier       | Description                                              | Outil utilise |
| ------------ | -------------------------------------------------------- | ------------- |
| **Metriques** | Valeurs numeriques agregees dans le temps (latence, CPU, requetes/s) | Prometheus    |
| **Logs**      | Evenements textuels emis par les applications            | Loki + Promtail |
| **Traces**    | Suivi d'une requete a travers les services (non implemente ici) | -             |

### Monitoring vs Observabilite

- **Monitoring** : surveillance reactive — on definit des seuils et on alerte quand ils sont depasses.
- **Observabilite** : capacite a comprendre l'etat interne d'un systeme a partir de ses sorties (metriques, logs, traces). Permet de diagnostiquer des problemes inconnus.

---

## Integration avec l'application

### Metriques backend (Express + prom-client)

Le backend expose un endpoint `/metrics` au format Prometheus avec :
- **Metriques par defaut** : CPU, memoire, event loop, GC (prefixe `gym_backend_`)
- **http_request_duration_seconds** : histogramme de la duree des requetes HTTP
- **http_requests_total** : compteur total de requetes par methode/route/code de statut

Prometheus scrape ce endpoint toutes les 15 secondes.

### Logs (Promtail + Docker)

Promtail utilise le Docker socket pour decouvrir automatiquement les conteneurs et collecter leurs logs stdout/stderr. Chaque log est enrichi avec :
- Nom du conteneur
- Nom du service Docker Compose
- Stream (stdout/stderr)

---

## Lancement de la stack

```bash
# 1. Demarrer l'application (blue/green ou standard)
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d

# 2. Demarrer la stack monitoring
docker compose -f docker-compose.monitoring.yml up -d
```

---

## Acces aux interfaces

| Service        | URL                      | Identifiants         |
| -------------- | ------------------------ | -------------------- |
| Grafana        | http://localhost:3000     | admin / admin        |
| Prometheus     | http://localhost:9090     | -                    |
| Loki           | http://localhost:3100     | interne              |
| Metriques backend | http://localhost/metrics | via le reverse proxy |

---

## Dashboards Grafana

### Dashboard 1 : Backend Metrics
- Requetes HTTP par seconde
- Latence (p50, p95, p99)
- Erreurs HTTP (4xx/5xx)
- Memoire (RSS, Heap)
- CPU usage
- Uptime du service

### Dashboard 2 : Logs Correles
- Logs backend (tous niveaux)
- Volume de logs par service
- Erreurs applicatives filtrees
- Latence + erreurs 5xx correlees

Les dashboards sont provisionnes automatiquement au demarrage de Grafana.
