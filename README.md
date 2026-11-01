# TLC HVFHV 2026 — Proyecto Final de Base de Datos

Proyecto final del curso **Base de Datos (MCD8008)** — UTEC. Analiza los registros
*High Volume For-Hire Vehicle* (HVFHV) de Nueva York (Uber y Lyft) de enero a mayo de 2026,
publicados por la *New York City Taxi and Limousine Commission*.

- **Parte 1:** modelo relacional en PostgreSQL (11 tablas, particionado mensual, calidad de datos, feature engineering).
- **Parte 2:** arquitectura especializada complementaria con **TimescaleDB** (series temporales) + **PostGIS** (espacial) para predicción de demanda y detección de anomalías.

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| Base transaccional | PostgreSQL 16 |
| Series temporales | TimescaleDB 2.31 |
| Espacial | PostGIS 3.6 |
| API | FastAPI + uvicorn |
| Cache | Redis 7 |
| Model registry | MLflow |
| Despliegue | Docker Compose |

## Estructura del repositorio

```
Parte 1/
  Sql/                  01..06 (esquemas, tablas, datos, consultas, índices, coordenadas)
  Datos/                CSVs (catálogos + muestra viaje/incidencia; NO versionados)
  1.Informe final.pdf
  2.Diagrama ER ... .pdf / .png
Parte 2/
  Sql/                  07_timescale.sql, 08_demo_queries.sql
  informe_final.pdf / .tex
  modelo_nosql.pdf / .tex
  arquitectura.pdf / .tex
  proceso_y_comparacion.html
deploy/
  docker-compose.yml    stack completo (db + redis + mlflow + api)
  setup.sh              bootstrap para EC2 (Ubuntu 22.04)
  api/                  FastAPI + frontend estático
```

## Requisitos

- Docker + Docker Compose (o Docker Desktop).
- Para compilar los PDFs: `pdflatex` (MiKTeX/TeX Live).

## Puesta en marcha

```bash
cd deploy
cp .env.example .env      # edita POSTGRES_PASSWORD
docker compose up -d --build
```

La API queda en `http://localhost:8000`, MLflow en `:5000`, y PostgreSQL en `:5432`.

## Datos

Los archivos de origen son los parquet mensuales `fhvhv_tripdata_2026-XX.parquet` de la TLC.
Debido al volumen (105 996 114 filas en el universo), se tomó una **muestra reproducible de
1 000 000 de filas por mes** (semilla 42), generando los CSV:

- `viaje_2026_XX.csv` (~1 M filas c/u, 27 columnas)
- `incidencia_2026_XX.csv` (incidencias de calidad)

Estos CSV **no están versionados** (superan el límite de 100 MB de GitHub). Deben ubicarse en
`Parte 1/Datos/` antes de la carga. Los catálogos (plataforma, borough, zonas, etc.) ya están
embebidos en `Parte 1/Sql/03_data.sql`, por lo que no se requieren archivos externos para ellos.

## Carga del modelo (Parte 1)

Dentro del contenedor (o apuntando a `localhost:5432`), en orden:

```bash
psql -U tlc -d tlc -f "Parte 1/Sql/01_schema.sql"
psql -U tlc -d tlc -f "Parte 1/Sql/02_tables.sql"
psql -U tlc -d tlc -f "Parte 1/Sql/03_data.sql"
psql -U tlc -d tlc -f "Parte 1/Sql/06_zonas_geo.sql"
```

Luego importa los CSV (con `\copy` y `NULL ''`):

```sql
\copy core.viaje FROM 'Parte 1/Datos/viaje_2026_01.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy auditoria.incidencia FROM 'Parte 1/Datos/incidencia_2026_01.csv' WITH (FORMAT csv, HEADER true, NULL '')
```

(Repite para los 5 meses). Después reconstruye el agregado horario:

```sql
INSERT INTO analytics.demanda_hora (mes_fuente, hora, zona_origen_id, plataforma_codigo, viajes)
SELECT mes_fuente, DATE_TRUNC('hour', recogida_at), zona_origen_id, plataforma_codigo, COUNT(*)
FROM core.viaje GROUP BY 1,2,3,4
ON CONFLICT DO NOTHING;
```

## Capa TimescaleDB + PostGIS (Parte 2)

```bash
psql -U tlc -d tlc -f "Parte 2/Sql/07_timescale.sql"   # geo + hypertable + continuous aggregate + compresión
psql -U tlc -d tlc -f "Parte 2/Sql/08_demo_queries.sql" # consultas temporales y espaciales
```

La extensión `postgis` debe habilitarse una vez:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

## Demo web (predicción + anomalías)

Con el stack levantado, abre `http://localhost:8000/`. Endpoints:

| Endpoint | Descripción |
|---|---|
| `GET /api/zones` | Lista de zonas |
| `GET /api/forecast/{zona_id}` | Pronóstico (baseline naive + promedio) e histórico 72 h |
| `GET /api/anomalies/{zona_id}` | Anomalías por z-score (> 2) |

## Resultados clave

- Viajes cargados: 4 999 931 (Uber 71.81 %, Lyft 28.19 %).
- Hypertable `demanda_serie`: 1 272 029 filas, 22 chunks comprimidos → **14 MB** (vs. 162 MB relacionales, ≈ 11.6×).
- Hora pico: 2026-02-07 19:00 (3 163 viajes); día pico: 2026-02-07 (47 981 viajes).

## Entregables (Parte 2)

- `Parte 2/informe_final.pdf`
- `Parte 2/modelo_nosql.pdf`
- `Parte 2/arquitectura.pdf`
- `Parte 2/proceso_y_comparacion.html`

## Autores

Sebastian Rodrigo García Villacorta, Dante Guillermo Barreto Daza,
Clinton Michael Chulluncuy Reynoso, Ronald Ramiro Hilario Orihuela.

Docente: Luis Alberto Chicoma Chevez — Base de Datos (MCD8008).
