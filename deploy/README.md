# TLC HVFHV 2026 - Despliegue (EC2 / Codespaces)

Stack para la Parte 2 del proyecto: PostgreSQL + TimescaleDB + PostGIS, Redis, MLflow y una API de inferencia (FastAPI).

## Servicios

| Servicio | Puerto | Imagen | Notas |
|---|---|---|---|
| `db` | 5432 | `timescale/timescaledb-ha:pg16` | Incluye PostGIS y pgvector |
| `redis` | 6379 | `redis:7-alpine` | Cache de features / inferencia |
| `mlflow` | 5000 | `ghcr.io/mlflow/mlflow` | Model registry |
| `api` | 8000 | build `./api` | FastAPI de inferencia |

## Uso local / Codespaces

```bash
cp .env.example .env   # edita POSTGRES_PASSWORD
docker compose up -d --build
```

## Uso en EC2 (Ubuntu 22.04)

```bash
git clone <este-repositorio>
cd <repo>/deploy
bash setup.sh
```

## Cargar el modelo relacional (Parte 1)

Dentro del contenedor `db` ya están TimescaleDB y PostGIS disponibles:

```bash
docker compose exec db psql -U tlc -d tlc \
  -c "CREATE EXTENSION IF NOT EXISTS timescaledb; CREATE EXTENSION IF NOT EXISTS postgis;"
```

Luego ejecuta tus scripts en orden: `01_schema.sql`, `02_tables.sql`, `03_data.sql`, `06_zonas_geo.sql`, y carga los CSV de `viaje`/`incidencia`.

## Seguridad

No expongas 5432/5000/8000 a `0.0.0.0/0`. Restringe el Security Group a tu IP o usa túnel SSH.
