-- ============================================================================
-- PROYECTO FINAL DE BASE DE DATOS - NYC TLC HVFHV 2026 - PARTE 2
-- 07_timescale.sql - CAPA ESPACIAL (PostGIS) + SERIE TEMPORAL (TimescaleDB)
-- Motor: PostgreSQL 16 + TimescaleDB 2.x + PostGIS 3.x
--
-- Caso: predicción de demanda espaciotemporal por zona y plataforma.
-- Este script NO reemplaza el modelo relacional: añade una capa analítica
-- complementaria (Polyglot Persistence) sobre los mismos datos.
-- ============================================================================

SET search_path TO core, auditoria, analytics, public;

-- ============================================================================
-- 1. CAPA ESPACIAL: columna geo (GEOGRAPHY) en core.zona_taxi
--    Se deriva de longitud/latitud ya cargadas. No altera el ER (atributo).
-- ============================================================================

ALTER TABLE core.zona_taxi
    ADD COLUMN IF NOT EXISTS geo GEOGRAPHY(POINT, 4326);

UPDATE core.zona_taxi
SET geo = ST_SetSRID(ST_MakePoint(longitud, latitud), 4326)::geography
WHERE longitud IS NOT NULL AND latitud IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_zona_taxi_geo
    ON core.zona_taxi USING GIST (geo);

-- ============================================================================
-- 2. HYPERTABLE DE DEMANDA (serie temporal)
--    La clave de tiempo es "hora"; se particiona automáticamente en chunks.
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.demanda_serie (
    hora            TIMESTAMPTZ NOT NULL,
    zona_origen_id  SMALLINT    NOT NULL,
    plataforma_codigo VARCHAR(10) NOT NULL,
    viajes          BIGINT      NOT NULL
);

SELECT create_hypertable('analytics.demanda_serie', 'hora',
                         if_not_exists => TRUE);

-- ============================================================================
-- 3. POBLAR DESDE EL AGREGADO RELACIONAL analytics.demanda_hora
-- ============================================================================

INSERT INTO analytics.demanda_serie
    (hora, zona_origen_id, plataforma_codigo, viajes)
SELECT hora::timestamptz, zona_origen_id, plataforma_codigo, viajes
FROM analytics.demanda_hora;

-- ============================================================================
-- 4. CONTINUOUS AGGREGATE DIARIO (se mantiene automáticamente)
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.demanda_diaria
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', hora) AS dia,
       zona_origen_id,
       plataforma_codigo,
       SUM(viajes) AS viajes,
       COUNT(*)     AS n_horas
FROM analytics.demanda_serie
GROUP BY dia, zona_origen_id, plataforma_codigo
WITH NO DATA;

CALL refresh_continuous_aggregate('analytics.demanda_diaria', NULL, NULL);

-- ============================================================================
-- 5. POLÍTICA DE COMPRESIÓN (segmentos por zona y plataforma, orden por hora)
-- ============================================================================

ALTER TABLE analytics.demanda_serie SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'zona_origen_id, plataforma_codigo',
    timescaledb.compress_orderby   = 'hora'
);

SELECT add_compression_policy('analytics.demanda_serie', INTERVAL '7 days');
