-- ============================================================================
-- PROYECTO FINAL DE BASE DE DATOS
-- NYC TLC HVFHV 2026
-- OPTIMIZACIÓN DE CONSULTAS E ÍNDICES
--
-- Ejecutar después de cargar core.viaje y analytics.demanda_hora.
-- El benchmark compara Q09 y Q10 antes y después de crear los índices.
-- ============================================================================

SET search_path TO core, auditoria, analytics, public;


-- ============================================================================
-- 1. PREPARACIÓN DEL EXPERIMENTO
--
-- Se actualizan las estadísticas y se deshabilita el paralelismo para aislar
-- el efecto de los índices y obtener planes comparables entre ambas fases.
-- ============================================================================

ANALYZE core.viaje;
SET max_parallel_workers_per_gather = 0;


-- ============================================================================
-- 2. ELIMINACIÓN DE ÍNDICES EXPERIMENTALES
--
-- Se eliminan únicamente los índices evaluados si existen de una ejecución
-- anterior. Las claves primarias y otros índices estructurales se conservan.
-- ============================================================================

DROP INDEX IF EXISTS core.idx_viaje_zona_recogida;
DROP INDEX IF EXISTS core.idx_viaje_plataforma_recogida;


-- ============================================================================
-- 3. FASE ANTES DE CREAR LOS ÍNDICES
-- ============================================================================


-- Q09. Plan estimado para la consulta por zona y rango temporal

EXPLAIN
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND zona_origen_id = 161
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- Q09. Plan real, tiempo de ejecución y bloques utilizados

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND zona_origen_id = 161
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- Q10. Plan estimado para la consulta por plataforma y rango temporal

EXPLAIN
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND plataforma_codigo = 'HV0005'
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- Q10. Plan real, tiempo de ejecución y bloques utilizados

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND plataforma_codigo = 'HV0005'
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- ============================================================================
-- 4. CREACIÓN DE ÍNDICES PROPUESTOS
--
-- El primer índice optimiza las consultas que filtran por zona de origen y
-- rango temporal. El segundo optimiza el acceso por plataforma y fecha.
-- ============================================================================

CREATE INDEX idx_viaje_zona_recogida
    ON core.viaje (zona_origen_id, recogida_at);

CREATE INDEX idx_viaje_plataforma_recogida
    ON core.viaje (plataforma_codigo, recogida_at);

ANALYZE core.viaje;


-- ============================================================================
-- 5. FASE DESPUÉS DE CREAR LOS ÍNDICES
--
-- Se utilizan exactamente los mismos predicados de la fase anterior para
-- comparar únicamente el efecto producido por los índices.
-- ============================================================================


-- Q09. Plan estimado para la consulta por zona y rango temporal

EXPLAIN
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND zona_origen_id = 161
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- Q09. Plan real, tiempo de ejecución y bloques utilizados

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND zona_origen_id = 161
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- Q10. Plan estimado para la consulta por plataforma y rango temporal

EXPLAIN
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND plataforma_codigo = 'HV0005'
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- Q10. Plan real, tiempo de ejecución y bloques utilizados

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND plataforma_codigo = 'HV0005'
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- ============================================================================
-- 6. ÍNDICE ANALÍTICO ADICIONAL
--
-- Este índice optimiza las consultas sobre el agregado horario que filtran
-- por zona de origen y rango temporal. No forma parte del benchmark.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_demanda_hora_zona_hora
    ON analytics.demanda_hora (zona_origen_id, hora);

ANALYZE analytics.demanda_hora;


-- ============================================================================
-- 7. VERIFICACIÓN DE ÍNDICES
--
-- La consulta muestra los índices registrados sobre core.viaje y
-- analytics.demanda_hora, junto con sus respectivas definiciones.
-- ============================================================================

SELECT schemaname AS esquema, tablename AS tabla,
       indexname AS indice, indexdef AS definicion
FROM pg_indexes
WHERE (schemaname = 'core' AND tablename = 'viaje')
   OR (schemaname = 'analytics' AND tablename = 'demanda_hora')
ORDER BY schemaname, tablename, indexname;


-- ============================================================================
-- 8. RESTAURACIÓN DE LA CONFIGURACIÓN
--
-- Se restablece el valor original del paralelismo para la sesión actual.
-- ============================================================================

RESET max_parallel_workers_per_gather;