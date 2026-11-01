-- ============================================================================
-- PROYECTO FINAL DE BASE DE DATOS - NYC TLC HVFHV 2026
-- 02_tables.sql - TABLAS, RESTRICCIONES Y COMENTARIOS
-- Motor: PostgreSQL 16+ | Herramienta: pgAdmin 4
-- Ejecutar después de 01_schema.sql.
--
-- Modelo de 11 tablas:
--   core.plataforma, core.base_operativa, core.borough, core.zona_servicio,
--   core.zona_taxi, core.periodo_mensual, core.lote_ingesta, core.viaje
--   (particionada por mes), core.regla_calidad;
--   auditoria.incidencia y analytics.demanda_hora.
-- ============================================================================

SET search_path TO core, auditoria, analytics, public;


-- ============================================================================
-- 1. CATÁLOGOS
-- ============================================================================

-- Plataformas HVFHV

CREATE TABLE core.plataforma (
    codigo VARCHAR(10) NOT NULL, nombre VARCHAR(50) NOT NULL,
    CONSTRAINT pk_plataforma PRIMARY KEY (codigo),
    CONSTRAINT uq_plataforma_nombre UNIQUE (nombre),
    CONSTRAINT ck_plataforma_codigo CHECK (codigo IN ('HV0002','HV0003','HV0004','HV0005'))
);

COMMENT ON TABLE core.plataforma IS
    'Plataformas HVFHV: Uber (HV0003) y Lyft (HV0005).';
COMMENT ON COLUMN core.plataforma.codigo IS
    'Código de licencia HVFHV publicado por TLC.';


-- Bases operativas

CREATE TABLE core.base_operativa (
    codigo VARCHAR(10) NOT NULL,
    CONSTRAINT pk_base_operativa PRIMARY KEY (codigo)
);

COMMENT ON TABLE core.base_operativa IS
    'Bases de despacho y recepción de solicitudes presentes en el conjunto.';


-- Boroughs de Nueva York y categorías territoriales adicionales

CREATE TABLE core.borough (
    borough_id SMALLINT NOT NULL, nombre VARCHAR(30) NOT NULL,
    CONSTRAINT pk_borough PRIMARY KEY (borough_id),
    CONSTRAINT uq_borough_nombre UNIQUE (nombre)
);

COMMENT ON TABLE core.borough IS
    'Categorías territoriales del catálogo TLC.';


-- Clasificación de las zonas según el tipo de servicio

CREATE TABLE core.zona_servicio (
    zona_servicio_id SMALLINT NOT NULL, nombre VARCHAR(30) NOT NULL,
    CONSTRAINT pk_zona_servicio PRIMARY KEY (zona_servicio_id),
    CONSTRAINT uq_zona_servicio_nombre UNIQUE (nombre)
);

COMMENT ON TABLE core.zona_servicio IS
    'Clasificación de servicio del catálogo; no representa un producto comercial.';


-- Catálogo oficial de zonas TLC

CREATE TABLE core.zona_taxi (
    location_id SMALLINT NOT NULL, nombre VARCHAR(100) NOT NULL,
    borough_id SMALLINT NOT NULL, zona_servicio_id SMALLINT NOT NULL,
    CONSTRAINT pk_zona_taxi PRIMARY KEY (location_id),
    CONSTRAINT fk_zona_taxi_borough FOREIGN KEY (borough_id)
        REFERENCES core.borough (borough_id),
    CONSTRAINT fk_zona_taxi_servicio FOREIGN KEY (zona_servicio_id)
        REFERENCES core.zona_servicio (zona_servicio_id),
    CONSTRAINT ck_zona_taxi_id CHECK (location_id BETWEEN 1 AND 265)
);

COMMENT ON TABLE core.zona_taxi IS
    'Catálogo oficial de 265 zonas. El nombre no es único, como ocurre con Corona 56 y 57.';


-- ============================================================================
-- 2. PERIODO MENSUAL Y LOTES DE INGESTA
-- ============================================================================

-- Periodos mensuales asociados con los archivos de origen

CREATE TABLE core.periodo_mensual (
    mes_fuente DATE NOT NULL,
    creado_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_periodo_mensual PRIMARY KEY (mes_fuente),
    CONSTRAINT ck_periodo_mensual_dia
        CHECK (mes_fuente = DATE_TRUNC('month', mes_fuente)::DATE)
);

COMMENT ON TABLE core.periodo_mensual IS
    'Mes de publicación del archivo fuente.';


-- Control de ejecución, trazabilidad y balance de cada lote

CREATE TABLE core.lote_ingesta (
    mes_fuente DATE NOT NULL, archivo VARCHAR(255) NOT NULL,
    sha256 CHAR(64) NOT NULL, filas_archivo BIGINT NOT NULL,
    filas_procesadas BIGINT NOT NULL, filas_cargadas BIGINT NOT NULL,
    filas_rechazadas BIGINT NOT NULL,
    estado VARCHAR(15) NOT NULL DEFAULT 'PENDING',
    tamano_bloque INTEGER NOT NULL DEFAULT 25000,
    actualizado_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_lote_ingesta PRIMARY KEY (mes_fuente),
    CONSTRAINT fk_lote_periodo FOREIGN KEY (mes_fuente)
        REFERENCES core.periodo_mensual (mes_fuente),
    CONSTRAINT ck_lote_estado
        CHECK (estado IN ('PENDING','RUNNING','COMPLETO','FALLIDO')),
    CONSTRAINT ck_lote_balance
        CHECK (filas_cargadas + filas_rechazadas = filas_procesadas
           AND filas_procesadas <= filas_archivo),
    CONSTRAINT ck_lote_sha CHECK (LENGTH(sha256) = 64)
);

COMMENT ON TABLE core.lote_ingesta IS
    'Control mensual del archivo: hash SHA-256, conteos, estado y tamaño de bloque.';
COMMENT ON COLUMN core.lote_ingesta.filas_archivo IS
    'Cantidad total de filas del archivo fuente.';
COMMENT ON COLUMN core.lote_ingesta.filas_procesadas IS
    'Filas leídas durante la carga reproducible utilizada en esta entrega.';


-- ============================================================================
-- 3. REGLAS DE CALIDAD
-- ============================================================================

-- Catálogo de validaciones aplicadas durante la ingesta

CREATE TABLE core.regla_calidad (
    codigo VARCHAR(40) NOT NULL, descripcion TEXT NOT NULL,
    severidad VARCHAR(15) NOT NULL,
    CONSTRAINT pk_regla_calidad PRIMARY KEY (codigo),
    CONSTRAINT ck_regla_severidad
        CHECK (severidad IN ('ADVERTENCIA','RECHAZO'))
);

COMMENT ON TABLE core.regla_calidad IS
    'Reglas de calidad aplicadas durante la ingesta, con severidad de advertencia o rechazo.';


-- ============================================================================
-- 4. TABLA DE VIAJES PARTICIONADA POR MES
--
-- La clave primaria combina el mes del archivo con el ordinal de la fila.
-- La tabla contiene dimensiones, marcas temporales, importes e indicadores.
-- ============================================================================

CREATE TABLE core.viaje (
    mes_fuente DATE NOT NULL, fila_fuente BIGINT NOT NULL,
    plataforma_codigo VARCHAR(10) NOT NULL,
    base_despacho_codigo VARCHAR(10), base_recepcion_codigo VARCHAR(10),
    zona_origen_id SMALLINT NOT NULL, zona_destino_id SMALLINT NOT NULL,
    solicitud_at TIMESTAMP, llegada_at TIMESTAMP,
    recogida_at TIMESTAMP NOT NULL, fin_at TIMESTAMP NOT NULL,
    distancia_millas NUMERIC(10,2) NOT NULL, duracion_seg INTEGER NOT NULL,
    tarifa_base NUMERIC(14,2), peajes NUMERIC(14,2), bcf NUMERIC(14,2),
    impuesto_ventas NUMERIC(14,2), recargo_congestion NUMERIC(14,2),
    tarifa_aeropuerto NUMERIC(14,2), propinas NUMERIC(14,2),
    pago_conductor NUMERIC(14,2), tarifa_cbd NUMERIC(14,2),
    compartido_solicitado BOOLEAN NOT NULL,
    compartido_realizado BOOLEAN NOT NULL,
    acceso_solicitado BOOLEAN NOT NULL,
    wav_solicitado BOOLEAN NOT NULL, wav_realizado BOOLEAN NOT NULL,

    CONSTRAINT pk_viaje PRIMARY KEY (mes_fuente, fila_fuente),
    CONSTRAINT fk_viaje_lote FOREIGN KEY (mes_fuente)
        REFERENCES core.lote_ingesta (mes_fuente),
    CONSTRAINT fk_viaje_plataforma FOREIGN KEY (plataforma_codigo)
        REFERENCES core.plataforma (codigo),
    CONSTRAINT fk_viaje_base_despacho FOREIGN KEY (base_despacho_codigo)
        REFERENCES core.base_operativa (codigo),
    CONSTRAINT fk_viaje_base_recepcion FOREIGN KEY (base_recepcion_codigo)
        REFERENCES core.base_operativa (codigo),
    CONSTRAINT fk_viaje_zona_origen FOREIGN KEY (zona_origen_id)
        REFERENCES core.zona_taxi (location_id),
    CONSTRAINT fk_viaje_zona_destino FOREIGN KEY (zona_destino_id)
        REFERENCES core.zona_taxi (location_id),

    CONSTRAINT ck_viaje_temporal CHECK (fin_at >= recogida_at),
    CONSTRAINT ck_viaje_distancia
        CHECK (distancia_millas >= 0 AND duracion_seg > 0),
    CONSTRAINT ck_viaje_zona
        CHECK (zona_origen_id BETWEEN 1 AND 265
           AND zona_destino_id BETWEEN 1 AND 265)
) PARTITION BY RANGE (mes_fuente);

COMMENT ON TABLE core.viaje IS
    'Un registro por viaje publicado. La clave primaria es (mes_fuente, fila_fuente).';
COMMENT ON COLUMN core.viaje.fila_fuente IS
    'Ordinal de la fila en el archivo mensual; es una clave técnica y no identifica al cliente.';
COMMENT ON COLUMN core.viaje.solicitud_at IS
    'Fecha de solicitud. Puede ser posterior a la recogida y generar una advertencia de calidad.';


-- ============================================================================
-- 5. PARTICIONES MENSUALES DE VIAJES
--
-- Cada partición almacena los viajes correspondientes a un mes de 2026.
-- ============================================================================

CREATE TABLE core.viaje_2026_01 PARTITION OF core.viaje
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE core.viaje_2026_02 PARTITION OF core.viaje
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE core.viaje_2026_03 PARTITION OF core.viaje
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE core.viaje_2026_04 PARTITION OF core.viaje
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE core.viaje_2026_05 PARTITION OF core.viaje
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');


-- ============================================================================
-- 6. INCIDENCIAS DE CALIDAD
--
-- La tabla conserva las incidencias detectadas para cada fila del archivo,
-- incluyendo aquellas que fueron rechazadas y no ingresaron en core.viaje.
-- ============================================================================

CREATE TABLE auditoria.incidencia (
    mes_fuente DATE NOT NULL, fila_fuente BIGINT NOT NULL,
    regla_codigo VARCHAR(40) NOT NULL,
    detalle JSONB NOT NULL DEFAULT '{}',
    registrada_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_incidencia
        PRIMARY KEY (mes_fuente, fila_fuente, regla_codigo),
    CONSTRAINT fk_incidencia_lote FOREIGN KEY (mes_fuente)
        REFERENCES core.lote_ingesta (mes_fuente),
    CONSTRAINT fk_incidencia_regla FOREIGN KEY (regla_codigo)
        REFERENCES core.regla_calidad (codigo)
);

COMMENT ON TABLE auditoria.incidencia IS
    'Incidencias por fila fuente. No referencia directamente a viaje porque una fila rechazada también genera una incidencia.';


-- ============================================================================
-- 7. AGREGADO HORARIO
--
-- La tabla almacena la demanda observada por mes, hora, zona de origen y
-- plataforma para facilitar las consultas analíticas.
-- ============================================================================

CREATE TABLE analytics.demanda_hora (
    mes_fuente DATE NOT NULL, hora TIMESTAMP NOT NULL,
    zona_origen_id SMALLINT NOT NULL,
    plataforma_codigo VARCHAR(10) NOT NULL, viajes BIGINT NOT NULL,
    CONSTRAINT pk_demanda_hora
        PRIMARY KEY (mes_fuente, hora, zona_origen_id, plataforma_codigo),
    CONSTRAINT fk_demanda_periodo FOREIGN KEY (mes_fuente)
        REFERENCES core.periodo_mensual (mes_fuente),
    CONSTRAINT fk_demanda_zona FOREIGN KEY (zona_origen_id)
        REFERENCES core.zona_taxi (location_id),
    CONSTRAINT fk_demanda_plataforma FOREIGN KEY (plataforma_codigo)
        REFERENCES core.plataforma (codigo)
);

COMMENT ON TABLE analytics.demanda_hora IS
    'Recogidas por mes, hora, zona de origen y plataforma; agregado derivado de core.viaje.';


-- ============================================================================
-- 8. VERIFICACIÓN DE TABLAS CREADAS
--
-- La consulta muestra todas las tablas base registradas en los esquemas core,
-- auditoria y analytics, incluidas las particiones mensuales.
-- ============================================================================

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('core', 'auditoria', 'analytics')
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;