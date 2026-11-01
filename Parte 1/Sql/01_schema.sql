

-- ============================================================================
-- PROYECTO FINAL DE BASE DE DATOS - NYC TLC HVFHV 2026
-- 01_schema.sql - ESQUEMAS
-- Motor: PostgreSQL 16+ | pgAdmin 4
--
-- Crea los esquemas core, auditoria y analytics.
-- Ejecutar primero, sobre una base vacia del proyecto.
-- ============================================================================

DROP SCHEMA IF EXISTS analytics CASCADE;
DROP SCHEMA IF EXISTS auditoria CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;

CREATE SCHEMA core;
CREATE SCHEMA auditoria;
CREATE SCHEMA analytics;

COMMENT ON SCHEMA core IS
    'Dominio, ingesta y reglas de calidad del modelo HVFHV.';
COMMENT ON SCHEMA auditoria IS
    'Incidencias de calidad por registro fuente, sin FK a viaje.';
COMMENT ON SCHEMA analytics IS
    'Agregado horario derivado y vistas de feature engineering.';

SET search_path TO core, auditoria, analytics, public;
