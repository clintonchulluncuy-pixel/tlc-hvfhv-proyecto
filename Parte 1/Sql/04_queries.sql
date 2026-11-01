-- ============================================================================
-- PROYECTO FINAL DE BASE DE DATOS
-- NYC TLC HVFHV 2026
-- CONSULTAS ANALÍTICAS Y FEATURE ENGINEERING
-- ============================================================================


-- ============================================================================
-- 1. VERIFICACIÓN DE VIAJES CARGADOS POR PARTICIÓN MENSUAL
-- ============================================================================

SELECT mes_fuente, COUNT(*) AS viajes
FROM core.viaje
GROUP BY mes_fuente
ORDER BY mes_fuente;


-- ============================================================================
-- 2. VALIDACIÓN DE INTEGRIDAD REFERENCIAL Y REGLAS DE NEGOCIO
-- ============================================================================

SELECT
    (SELECT COUNT(*) FROM core.viaje v LEFT JOIN core.plataforma p
     ON p.codigo = v.plataforma_codigo WHERE p.codigo IS NULL)
     AS huerfanos_plataforma,

    (SELECT COUNT(*) FROM core.viaje v LEFT JOIN core.zona_taxi z
     ON z.location_id = v.zona_origen_id WHERE z.location_id IS NULL)
     AS huerfanos_zona_origen,

    (SELECT COUNT(*) FROM core.viaje v LEFT JOIN core.zona_taxi z
     ON z.location_id = v.zona_destino_id WHERE z.location_id IS NULL)
     AS huerfanos_zona_destino,

    (SELECT COUNT(*) FROM core.viaje
     WHERE fin_at < recogida_at OR distancia_millas < 0 OR duracion_seg <= 0)
     AS violaciones_reglas;


-- Resumen de incidencias registradas por mes y regla de calidad

SELECT mes_fuente, regla_codigo, COUNT(*) AS observaciones
FROM auditoria.incidencia
GROUP BY mes_fuente, regla_codigo
ORDER BY mes_fuente, regla_codigo;


-- ============================================================================
-- 3. CONFIGURACIÓN DEL ESQUEMA DE TRABAJO
-- ============================================================================

SET search_path TO core, auditoria, analytics, public;


-- ============================================================================
-- 4. VISTA ANALÍTICA PARA MODELADO PREDICTIVO
--
-- Unidad predictiva:
--     hora, zona_origen_id y plataforma_codigo
--
-- Variable objetivo:
--     viajes_objetivo
--
-- La vista genera una malla horaria completa e incorpora variables temporales,
-- rezagos de demanda y promedios móviles.
-- ============================================================================

CREATE OR REPLACE VIEW analytics.v_features_demanda AS
WITH horas AS (
    SELECT l.mes_fuente, g.hora
    FROM core.lote_ingesta l
    CROSS JOIN LATERAL generate_series(
        l.mes_fuente::TIMESTAMP,
        (l.mes_fuente + INTERVAL '1 month')::TIMESTAMP - INTERVAL '1 hour',
        INTERVAL '1 hour'
    ) AS g(hora)
    WHERE l.estado = 'COMPLETO'
),
panel AS (
    SELECT h.mes_fuente, h.hora, z.location_id AS zona_origen_id,
           p.codigo AS plataforma_codigo,
           COALESCE(d.viajes, 0)::BIGINT AS viajes_objetivo
    FROM horas h
    CROSS JOIN core.zona_taxi z
    CROSS JOIN core.plataforma p
    LEFT JOIN analytics.demanda_hora d
      ON d.mes_fuente = h.mes_fuente AND d.hora = h.hora
     AND d.zona_origen_id = z.location_id
     AND d.plataforma_codigo = p.codigo
),
rezagos AS (
    SELECT x.*,
           LAG(hora, 1) OVER w AS hora_1h,
           LAG(viajes_objetivo, 1) OVER w AS viajes_1h,
           LAG(hora, 24) OVER w AS hora_24h,
           LAG(viajes_objetivo, 24) OVER w AS viajes_24h,
           LAG(hora, 168) OVER w AS hora_168h,
           LAG(viajes_objetivo, 168) OVER w AS viajes_168h,
           MIN(hora) OVER w3 AS inicio_3h,
           COUNT(*) OVER w3 AS n_3h,
           AVG(viajes_objetivo) OVER w3 AS prom_3h,
           MIN(hora) OVER w24 AS inicio_24h,
           COUNT(*) OVER w24 AS n_24h,
           AVG(viajes_objetivo) OVER w24 AS prom_24h
    FROM panel x
    WINDOW
        w AS (
            PARTITION BY zona_origen_id, plataforma_codigo ORDER BY hora
        ),
        w3 AS (
            PARTITION BY zona_origen_id, plataforma_codigo ORDER BY hora
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ),
        w24 AS (
            PARTITION BY zona_origen_id, plataforma_codigo ORDER BY hora
            ROWS BETWEEN 24 PRECEDING AND 1 PRECEDING
        )
)
SELECT mes_fuente, hora, zona_origen_id, plataforma_codigo, viajes_objetivo,
       EXTRACT(HOUR FROM hora)::INTEGER AS hora_dia,
       EXTRACT(ISODOW FROM hora)::INTEGER AS dia_semana,
       (EXTRACT(ISODOW FROM hora) IN (6, 7)) AS fin_semana,
       CASE WHEN hora_1h = hora - INTERVAL '1 hour'
            THEN viajes_1h END AS demanda_1h_previa,
       CASE WHEN hora_24h = hora - INTERVAL '24 hours'
            THEN viajes_24h END AS demanda_misma_hora_dia_anterior,
       CASE WHEN hora_168h = hora - INTERVAL '168 hours'
            THEN viajes_168h END AS demanda_misma_hora_semana_anterior,
       CASE WHEN n_3h = 3 AND inicio_3h = hora - INTERVAL '3 hours'
            THEN ROUND(prom_3h, 2) END AS promedio_3h_previas,
       CASE WHEN n_24h = 24 AND inicio_24h = hora - INTERVAL '24 hours'
            THEN ROUND(prom_24h, 2) END AS promedio_24h_previas
FROM rezagos;


COMMENT ON VIEW analytics.v_features_demanda IS
'Malla horaria por zona y plataforma con variables históricas y controles de continuidad temporal.';


-- ============================================================================
-- Q01. VIAJES REGISTRADOS POR PLATAFORMA Y MES
--
-- Objetivo:
-- Determinar el volumen mensual de viajes correspondiente a cada plataforma.
--
-- Técnicas:
-- JOIN, SUM, GROUP BY y ORDER BY.
-- ============================================================================

SELECT TO_CHAR(d.mes_fuente, 'YYYY-MM') AS mes,
       p.nombre AS plataforma, SUM(d.viajes)::BIGINT AS viajes
FROM analytics.demanda_hora d
JOIN core.plataforma p ON p.codigo = d.plataforma_codigo
GROUP BY d.mes_fuente, p.nombre
ORDER BY d.mes_fuente, p.nombre;


-- ============================================================================
-- Q02. DISTRIBUCIÓN DE VIAJES POR BOROUGH Y PLATAFORMA
--
-- Objetivo:
-- Identificar los boroughs que concentran el mayor número de viajes para cada
-- plataforma.
--
-- Técnicas:
-- Múltiples JOIN, SUM, GROUP BY y ORDER BY.
-- ============================================================================

SELECT b.nombre AS borough, p.nombre AS plataforma,
       SUM(d.viajes)::BIGINT AS viajes
FROM analytics.demanda_hora d
JOIN core.zona_taxi z ON z.location_id = d.zona_origen_id
JOIN core.borough b ON b.borough_id = z.borough_id
JOIN core.plataforma p ON p.codigo = d.plataforma_codigo
GROUP BY b.nombre, p.nombre
ORDER BY viajes DESC, b.nombre;


-- ============================================================================
-- Q03. PRINCIPALES PARES ORIGEN-DESTINO
--
-- Objetivo:
-- Identificar los veinte pares origen-destino más frecuentes del último mes
-- completo y calcular su duración media.
--
-- Técnicas:
-- Subconsulta, doble JOIN, GROUP BY, agregaciones y LIMIT.
-- ============================================================================

SELECT v.zona_origen_id, zo.nombre AS zona_origen,
       v.zona_destino_id, zd.nombre AS zona_destino,
       COUNT(*)::BIGINT AS viajes,
       ROUND(AVG(v.duracion_seg / 60.0)::NUMERIC, 2) AS duracion_media_min
FROM core.viaje v
JOIN core.zona_taxi zo ON zo.location_id = v.zona_origen_id
JOIN core.zona_taxi zd ON zd.location_id = v.zona_destino_id
WHERE v.mes_fuente = (
    SELECT MAX(mes_fuente) FROM core.lote_ingesta WHERE estado = 'COMPLETO'
)
GROUP BY v.zona_origen_id, zo.nombre, v.zona_destino_id, zd.nombre
ORDER BY viajes DESC, v.zona_origen_id, v.zona_destino_id
LIMIT 20;


-- ============================================================================
-- Q04. TIEMPO PROMEDIO DE ESPERA POR ZONA Y PLATAFORMA
--
-- Objetivo:
-- Identificar las zonas y plataformas con mayores tiempos promedio entre la
-- solicitud del servicio y la recogida.
--
-- Técnicas:
-- Agregaciones condicionadas, FILTER, HAVING y subconsulta.
-- ============================================================================

SELECT v.zona_origen_id, z.nombre AS zona, p.nombre AS plataforma,
       COUNT(*) FILTER (WHERE v.solicitud_at IS NOT NULL)
           AS viajes_con_solicitud,
       COUNT(*) FILTER (
           WHERE v.solicitud_at IS NOT NULL
             AND v.solicitud_at <= v.recogida_at
             AND v.recogida_at - v.solicitud_at <= INTERVAL '4 hours'
       ) AS esperas_validas,
       ROUND(
           AVG(EXTRACT(EPOCH FROM (v.recogida_at - v.solicitud_at)) / 60.0)
           FILTER (
               WHERE v.solicitud_at IS NOT NULL
                 AND v.solicitud_at <= v.recogida_at
                 AND v.recogida_at - v.solicitud_at <= INTERVAL '4 hours'
           )::NUMERIC, 2
       ) AS espera_promedio_min
FROM core.viaje v
JOIN core.zona_taxi z ON z.location_id = v.zona_origen_id
JOIN core.plataforma p ON p.codigo = v.plataforma_codigo
WHERE v.mes_fuente = (
    SELECT MAX(mes_fuente) FROM core.lote_ingesta WHERE estado = 'COMPLETO'
)
GROUP BY v.zona_origen_id, z.nombre, p.nombre
HAVING COUNT(*) >= 1000
ORDER BY espera_promedio_min DESC NULLS LAST, v.zona_origen_id, p.nombre
LIMIT 20;


-- ============================================================================
-- Q05. CRECIMIENTO MENSUAL DE RECOGIDAS POR ZONA
--
-- Objetivo:
-- Identificar las zonas que presentaron el mayor incremento en su promedio
-- diario de recogidas respecto del mes inmediatamente anterior.
--
-- Técnicas:
-- CTE, LAG, ROW_NUMBER y comparación de promedios diarios.
-- ============================================================================

WITH mensual AS (
    SELECT d.mes_fuente, d.zona_origen_id,
           SUM(d.viajes)::NUMERIC /
           ((d.mes_fuente + INTERVAL '1 month')::DATE - d.mes_fuente)
           AS viajes_diarios
    FROM analytics.demanda_hora d
    JOIN core.lote_ingesta l
      ON l.mes_fuente = d.mes_fuente AND l.estado = 'COMPLETO'
    GROUP BY d.mes_fuente, d.zona_origen_id
),
comparacion AS (
    SELECT m.*,
           LAG(m.mes_fuente) OVER (
               PARTITION BY m.zona_origen_id ORDER BY m.mes_fuente
           ) AS mes_anterior,
           LAG(m.viajes_diarios) OVER (
               PARTITION BY m.zona_origen_id ORDER BY m.mes_fuente
           ) AS promedio_anterior
    FROM mensual m
),
comparables AS (
    SELECT c.mes_fuente, c.zona_origen_id, c.viajes_diarios,
           c.promedio_anterior,
           ROUND(
               100 * (c.viajes_diarios - c.promedio_anterior) /
               NULLIF(c.promedio_anterior, 0), 2
           ) AS variacion_pct
    FROM comparacion c
    WHERE c.mes_anterior = (c.mes_fuente - INTERVAL '1 month')::DATE
      AND c.promedio_anterior > 0
),
rankeado AS (
    SELECT x.*,
           ROW_NUMBER() OVER (
               PARTITION BY x.mes_fuente
               ORDER BY x.variacion_pct DESC, x.zona_origen_id
           ) AS posicion
    FROM comparables x
)
SELECT r.mes_fuente, r.zona_origen_id, z.nombre AS zona,
       ROUND(r.viajes_diarios, 2) AS viajes_diarios,
       ROUND(r.promedio_anterior, 2) AS promedio_diario_anterior,
       r.variacion_pct, r.posicion
FROM rankeado r
JOIN core.zona_taxi z ON z.location_id = r.zona_origen_id
WHERE r.posicion <= 15
ORDER BY r.mes_fuente, r.posicion;


-- ============================================================================
-- Q06. VARIACIÓN DE DEMANDA ENTRE HORAS CONSECUTIVAS
--
-- Objetivo:
-- Analizar los cambios de demanda entre horas consecutivas para la zona 161
-- durante el día 15 del último mes completo.
--
-- Técnicas:
-- Vista analítica, CASE y análisis temporal.
-- ============================================================================

SELECT hora, plataforma_codigo, viajes_objetivo, demanda_1h_previa,
       viajes_objetivo - demanda_1h_previa AS cambio_absoluto,
       CASE WHEN demanda_1h_previa > 0
            THEN ROUND(
                100.0 * (viajes_objetivo - demanda_1h_previa) /
                demanda_1h_previa, 2
            )
       END AS cambio_pct
FROM analytics.v_features_demanda
WHERE zona_origen_id = 161
  AND hora >= (
      SELECT MAX(mes_fuente)::TIMESTAMP + INTERVAL '14 days'
      FROM core.lote_ingesta WHERE estado = 'COMPLETO'
  )
  AND hora < (
      SELECT MAX(mes_fuente)::TIMESTAMP + INTERVAL '15 days'
      FROM core.lote_ingesta WHERE estado = 'COMPLETO'
  )
ORDER BY hora, plataforma_codigo;


-- ============================================================================
-- Q07. VIAJES COMPARTIDOS Y SERVICIOS WAV
--
-- Objetivo:
-- Analizar el volumen de viajes compartidos y servicios WAV del último mes
-- completo.
--
-- WAV:
-- Vehículos accesibles para personas usuarias de sillas de ruedas.
--
-- Técnicas:
-- Agregaciones condicionadas y FILTER.
-- ============================================================================

SELECT p.nombre AS plataforma, COUNT(*)::BIGINT AS viajes,
       COUNT(*) FILTER (WHERE v.compartido_solicitado IS TRUE)
           AS compartido_solicitado,
       COUNT(*) FILTER (WHERE v.compartido_realizado IS TRUE)
           AS compartido_realizado,
       ROUND(
           100.0 * COUNT(*) FILTER (WHERE v.compartido_realizado IS TRUE) /
           NULLIF(
               COUNT(*) FILTER (WHERE v.compartido_realizado IS NOT NULL), 0
           ), 2
       ) AS pct_viajes_compartidos,
       COUNT(*) FILTER (WHERE v.wav_solicitado IS TRUE)
           AS wav_solicitado,
       COUNT(*) FILTER (WHERE v.wav_realizado IS TRUE)
           AS wav_realizado
FROM core.viaje v
JOIN core.plataforma p ON p.codigo = v.plataforma_codigo
WHERE v.mes_fuente = (
    SELECT MAX(mes_fuente) FROM core.lote_ingesta WHERE estado = 'COMPLETO'
)
GROUP BY p.nombre
ORDER BY p.nombre;


-- ============================================================================
-- Q08. EVOLUCIÓN DE TARIFAS Y PAGOS AL CONDUCTOR
--
-- Objetivo:
-- Analizar la evolución mensual de la tarifa base y del pago al conductor
-- para cada plataforma.
--
-- Técnicas:
-- COUNT, AVG, SUM, GROUP BY y ORDER BY.
-- ============================================================================

SELECT v.mes_fuente, p.nombre AS plataforma, COUNT(*) AS viajes,
       COUNT(v.tarifa_base) AS con_tarifa,
       ROUND(AVG(v.tarifa_base), 2) AS tarifa_base_media_usd,
       COUNT(v.pago_conductor) AS con_pago,
       ROUND(AVG(v.pago_conductor), 2) AS pago_conductor_medio_usd,
       ROUND(SUM(v.tarifa_base), 2) AS suma_tarifa_base_usd,
       ROUND(SUM(v.pago_conductor), 2) AS suma_pago_conductor_usd
FROM core.viaje v
JOIN core.plataforma p ON p.codigo = v.plataforma_codigo
GROUP BY v.mes_fuente, p.nombre
ORDER BY v.mes_fuente, p.nombre;


-- ============================================================================
-- Q09. VIAJES RECOGIDOS EN MIDTOWN CENTER
--
-- Objetivo:
-- Contabilizar los viajes recogidos en Midtown Center, zona 161, entre las
-- 08:00 y 09:00 del 15 de enero de 2026.
--
-- Técnicas:
-- Filtro por zona y rango temporal semiabierto.
-- ============================================================================

SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND zona_origen_id = 161
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- ============================================================================
-- Q10. VIAJES DE LYFT EN UN RANGO HORARIO
--
-- Objetivo:
-- Contabilizar los viajes de Lyft recogidos entre las 08:00 y 09:00 del
-- 15 de enero de 2026.
--
-- La plataforma Lyft está identificada mediante el código HV0005.
--
-- Técnicas:
-- Filtro por plataforma y rango temporal semiabierto.
-- ============================================================================

SELECT COUNT(*)::BIGINT AS viajes
FROM core.viaje
WHERE mes_fuente = DATE '2026-01-01' AND plataforma_codigo = 'HV0005'
  AND recogida_at >= TIMESTAMP '2026-01-15 08:00:00'
  AND recogida_at <  TIMESTAMP '2026-01-15 09:00:00';


-- ============================================================================
-- Q11. CONTROL DE CARGA E INCIDENCIAS DE CALIDAD
--
-- Objetivo:
-- Verificar las filas procesadas, cargadas y rechazadas en cada lote, así como
-- las incidencias registradas según su nivel de severidad.
--
-- Técnicas:
-- LEFT JOIN, FILTER, COUNT y GROUP BY.
-- ============================================================================

SELECT l.mes_fuente, l.estado, l.filas_archivo, l.filas_procesadas,
       l.filas_cargadas, l.filas_rechazadas,
       COUNT(i.regla_codigo) FILTER (WHERE r.severidad = 'ADVERTENCIA')
           AS advertencias,
       COUNT(i.regla_codigo) FILTER (WHERE r.severidad = 'RECHAZO')
           AS motivos_de_rechazo
FROM core.lote_ingesta l
LEFT JOIN auditoria.incidencia i ON i.mes_fuente = l.mes_fuente
LEFT JOIN core.regla_calidad r ON r.codigo = i.regla_codigo
GROUP BY l.mes_fuente, l.estado, l.filas_archivo, l.filas_procesadas,
         l.filas_cargadas, l.filas_rechazadas
ORDER BY l.mes_fuente;


-- ============================================================================
-- Q12. CLASIFICACIÓN MENSUAL DE BOROUGHS
--
-- Objetivo:
-- Evaluar los cambios en la posición de cada borough según su volumen mensual
-- de recogidas.
--
-- Técnicas:
-- CTE, DENSE_RANK y ROW_NUMBER.
-- ============================================================================

WITH mensual AS (
    SELECT d.mes_fuente, b.borough_id, b.nombre AS borough,
           SUM(d.viajes)::BIGINT AS viajes
    FROM analytics.demanda_hora d
    JOIN core.zona_taxi z ON z.location_id = d.zona_origen_id
    JOIN core.borough b ON b.borough_id = z.borough_id
    GROUP BY d.mes_fuente, b.borough_id, b.nombre
),
posiciones AS (
    SELECT m.*,
           DENSE_RANK() OVER (
               PARTITION BY mes_fuente ORDER BY viajes DESC
           ) AS rango,
           ROW_NUMBER() OVER (
               PARTITION BY mes_fuente ORDER BY viajes DESC, borough_id
           ) AS posicion
    FROM mensual m
)
SELECT mes_fuente, borough, viajes, rango, posicion
FROM posiciones
WHERE posicion <= 7
ORDER BY mes_fuente, posicion;


-- ============================================================================
-- 5. FEATURE ENGINEERING MEDIANTE SQL
--
-- Unidad predictiva:
--     hora, zona_origen_id y plataforma_codigo
--
-- Variable objetivo:
--     viajes_objetivo
--
-- Las variables históricas se calculan únicamente con información anterior
-- al periodo objetivo para evitar fuga temporal.
-- ============================================================================


-- ============================================================================
-- F01. EXTRACCIÓN DE VARIABLES PARA MODELADO
--
-- Objetivo:
-- Consultar las variables temporales, rezagos y promedios móviles de la
-- zona 161 durante los días 15 y 16 del último mes completo.
-- ============================================================================

SELECT hora, zona_origen_id, plataforma_codigo, viajes_objetivo,
       hora_dia, dia_semana, fin_semana, demanda_1h_previa,
       demanda_misma_hora_dia_anterior,
       demanda_misma_hora_semana_anterior,
       promedio_3h_previas, promedio_24h_previas
FROM analytics.v_features_demanda
WHERE zona_origen_id = 161
  AND hora >= (
      SELECT MAX(mes_fuente)::TIMESTAMP + INTERVAL '14 days'
      FROM core.lote_ingesta WHERE estado = 'COMPLETO'
  )
  AND hora < (
      SELECT MAX(mes_fuente)::TIMESTAMP + INTERVAL '16 days'
      FROM core.lote_ingesta WHERE estado = 'COMPLETO'
  )
ORDER BY hora, plataforma_codigo;