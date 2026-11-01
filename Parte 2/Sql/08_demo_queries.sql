-- ============================================================================
-- 08_demo_queries.sql - PARTE 2: CONSULTAS DE DEMOSTRACIÓN
-- Resultados reales sobre la capa TimescaleDB + PostGIS.
-- ============================================================================

SET search_path TO core, auditoria, analytics, public;

-- ============================================================================
-- D1. CARACTERIZACIÓN: volumen total y por plataforma (muestra cargada)
-- ============================================================================
SELECT COUNT(*)::BIGINT AS viajes_totales FROM core.viaje;

SELECT p.nombre AS plataforma, COUNT(*)::BIGINT AS viajes
FROM core.viaje v
JOIN core.plataforma p ON p.codigo = v.plataforma_codigo
GROUP BY p.nombre ORDER BY viajes DESC;

-- ============================================================================
-- D2. HYPERTABLE: chunks y compresión
-- ============================================================================
SELECT hypertable_name, num_dimensions
FROM timescaledb_information.hypertables
WHERE hypertable_name = 'demanda_serie';

SELECT COUNT(*) AS chunks
FROM timescaledb_information.chunks
WHERE hypertable_name = 'demanda_serie';

-- ============================================================================
-- D3. TEMPORAL: hora pico de demanda global (time_bucket)
-- ============================================================================
SELECT time_bucket('1 hour', hora) AS hora,
       SUM(viajes)::BIGINT AS viajes
FROM analytics.demanda_serie
GROUP BY 1
ORDER BY viajes DESC
LIMIT 5;

-- ============================================================================
-- D4. TEMPORAL: top 5 días con mayor demanda (continuous aggregate)
-- ============================================================================
SELECT dia::date AS dia, SUM(viajes)::BIGINT AS viajes
FROM analytics.demanda_diaria
GROUP BY dia
ORDER BY viajes DESC
LIMIT 5;

-- ============================================================================
-- D5. ESPACIAL: top zonas por demanda en un radio de 2 km de Midtown (161)
-- ============================================================================
SELECT z.nombre AS zona, SUM(d.viajes)::BIGINT AS viajes
FROM analytics.demanda_serie d
JOIN core.zona_taxi z ON z.location_id = d.zona_origen_id
JOIN core.zona_taxi c ON c.location_id = 161
WHERE ST_DWithin(z.geo, c.geo, 2000)
GROUP BY z.nombre
ORDER BY viajes DESC
LIMIT 10;

-- ============================================================================
-- D6. ESPACIAL: kNN - zonas más cercanas a JFK Airport (132)
-- ============================================================================
SELECT z.location_id, z.nombre,
       ROUND(ST_Distance(z.geo, j.geo)::numeric, 0) AS dist_m
FROM core.zona_taxi z
CROSS JOIN core.zona_taxi j
WHERE j.location_id = 132 AND z.location_id <> 132
ORDER BY z.geo <-> j.geo
LIMIT 5;

-- ============================================================================
-- D7. ESPACIAL: distancia haversine entre centroides (Midtown vs JFK)
--     y comparación con la distancia real reportada en viajes 161 -> 132
-- ============================================================================
SELECT ROUND(ST_Distance(a.geo, b.geo)::numeric, 0) AS dist_centroides_m,
       ROUND((ST_Distance(a.geo, b.geo) / 1609.34)::numeric, 2) AS dist_millas
FROM core.zona_taxi a, core.zona_taxi b
WHERE a.location_id = 161 AND b.location_id = 132;

SELECT COUNT(*)::BIGINT AS viajes,
       ROUND(AVG(distancia_millas)::numeric, 2) AS distancia_media_millas
FROM core.viaje
WHERE zona_origen_id = 161 AND zona_destino_id = 132;
