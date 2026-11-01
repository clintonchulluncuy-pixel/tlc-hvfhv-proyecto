-- ============================================================================
-- PROYECTO FINAL DE BASE DE DATOS - NYC TLC HVFHV 2026
-- 03_data.sql - CATÁLOGOS, LOTES, REGLAS Y AGREGADO HORARIO
--
-- Ejecutar después de 02_tables.sql. Los catálogos y lotes utilizan
-- ON CONFLICT para permitir la ejecución repetida del script.
-- El agregado horario debe ejecutarse después de importar core.viaje.
-- ============================================================================

SET search_path TO core, auditoria, analytics, public;


-- ============================================================================
-- 1. CATÁLOGO DE PLATAFORMAS
-- ============================================================================

INSERT INTO core.plataforma (codigo, nombre) VALUES
    ('HV0003', 'Uber'), ('HV0005', 'Lyft')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 2. CATÁLOGO DE BASES OPERATIVAS
-- ============================================================================

INSERT INTO core.base_operativa (codigo) VALUES
    ('B00887'), ('B01312'), ('B02003'), ('B02026'),
    ('B02465'), ('B02878'), ('B03404'), ('B03406')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 3. CATÁLOGO DE BOROUGHS
-- ============================================================================

INSERT INTO core.borough (borough_id, nombre) VALUES
    (1, 'Bronx'), (2, 'Brooklyn'), (3, 'EWR'), (4, 'Manhattan'),
    (5, 'Outside of NYC'), (6, 'Queens'), (7, 'Staten Island'), (8, 'Unknown')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 4. CATÁLOGO DE ZONAS DE SERVICIO
-- ============================================================================

INSERT INTO core.zona_servicio (zona_servicio_id, nombre) VALUES
    (1, 'Airports'), (2, 'Boro Zone'), (3, 'EWR'),
    (4, 'Unknown'), (5, 'Yellow Zone')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 5. CATÁLOGO DE ZONAS TLC
--
-- Cada zona se relaciona con un borough y una zona de servicio.
-- ============================================================================

INSERT INTO core.zona_taxi
    (location_id, nombre, borough_id, zona_servicio_id)
VALUES
    (1, 'Newark Airport', 3, 3),
    (2, 'Jamaica Bay', 6, 2),
    (3, 'Allerton/Pelham Gardens', 1, 2),
    (4, 'Alphabet City', 4, 5),
    (5, 'Arden Heights', 7, 2),
    (6, 'Arrochar/Fort Wadsworth', 7, 2),
    (7, 'Astoria', 6, 2),
    (8, 'Astoria Park', 6, 2),
    (9, 'Auburndale', 6, 2),
    (10, 'Baisley Park', 6, 2),
    (11, 'Bath Beach', 2, 2),
    (12, 'Battery Park', 4, 5),
    (13, 'Battery Park City', 4, 5),
    (14, 'Bay Ridge', 2, 2),
    (15, 'Bay Terrace/Fort Totten', 6, 2),
    (16, 'Bayside', 6, 2),
    (17, 'Bedford', 2, 2),
    (18, 'Bedford Park', 1, 2),
    (19, 'Bellerose', 6, 2),
    (20, 'Belmont', 1, 2),
    (21, 'Bensonhurst East', 2, 2),
    (22, 'Bensonhurst West', 2, 2),
    (23, 'Bloomfield/Emerson Hill', 7, 2),
    (24, 'Bloomingdale', 4, 5),
    (25, 'Boerum Hill', 2, 2),
    (26, 'Borough Park', 2, 2),
    (27, 'Breezy Point/Fort Tilden/Riis Beach', 6, 2),
    (28, 'Briarwood/Jamaica Hills', 6, 2),
    (29, 'Brighton Beach', 2, 2),
    (30, 'Broad Channel', 6, 2),
    (31, 'Bronx Park', 1, 2),
    (32, 'Bronxdale', 1, 2),
    (33, 'Brooklyn Heights', 2, 2),
    (34, 'Brooklyn Navy Yard', 2, 2),
    (35, 'Brownsville', 2, 2),
    (36, 'Bushwick North', 2, 2),
    (37, 'Bushwick South', 2, 2),
    (38, 'Cambria Heights', 6, 2),
    (39, 'Canarsie', 2, 2),
    (40, 'Carroll Gardens', 2, 2),
    (41, 'Central Harlem', 4, 2),
    (42, 'Central Harlem North', 4, 2),
    (43, 'Central Park', 4, 5),
    (44, 'Charleston/Tottenville', 7, 2),
    (45, 'Chinatown', 4, 5),
    (46, 'City Island', 1, 2),
    (47, 'Claremont/Bathgate', 1, 2),
    (48, 'Clinton East', 4, 5),
    (49, 'Clinton Hill', 2, 2),
    (50, 'Clinton West', 4, 5),
    (51, 'Co-Op City', 1, 2),
    (52, 'Cobble Hill', 2, 2),
    (53, 'College Point', 6, 2),
    (54, 'Columbia Street', 2, 2),
    (55, 'Coney Island', 2, 2),
    (56, 'Corona', 6, 2),
    (57, 'Corona', 6, 2),
    (58, 'Country Club', 1, 2),
    (59, 'Crotona Park', 1, 2),
    (60, 'Crotona Park East', 1, 2),
    (61, 'Crown Heights North', 2, 2),
    (62, 'Crown Heights South', 2, 2),
    (63, 'Cypress Hills', 2, 2),
    (64, 'Douglaston', 6, 2),
    (65, 'Downtown Brooklyn/MetroTech', 2, 2),
    (66, 'DUMBO/Vinegar Hill', 2, 2),
    (67, 'Dyker Heights', 2, 2),
    (68, 'East Chelsea', 4, 5),
    (69, 'East Concourse/Concourse Village', 1, 2),
    (70, 'East Elmhurst', 6, 2),
    (71, 'East Flatbush/Farragut', 2, 2),
    (72, 'East Flatbush/Remsen Village', 2, 2),
    (73, 'East Flushing', 6, 2),
    (74, 'East Harlem North', 4, 2),
    (75, 'East Harlem South', 4, 2),
    (76, 'East New York', 2, 2),
    (77, 'East New York/Pennsylvania Avenue', 2, 2),
    (78, 'East Tremont', 1, 2),
    (79, 'East Village', 4, 5),
    (80, 'East Williamsburg', 2, 2),
    (81, 'Eastchester', 1, 2),
    (82, 'Elmhurst', 6, 2),
    (83, 'Elmhurst/Maspeth', 6, 2),
    (84, 'Eltingville/Annadale/Prince''s Bay', 7, 2),
    (85, 'Erasmus', 2, 2),
    (86, 'Far Rockaway', 6, 2),
    (87, 'Financial District North', 4, 5),
    (88, 'Financial District South', 4, 5),
    (89, 'Flatbush/Ditmas Park', 2, 2),
    (90, 'Flatiron', 4, 5),
    (91, 'Flatlands', 2, 2),
    (92, 'Flushing', 6, 2),
    (93, 'Flushing Meadows-Corona Park', 6, 2),
    (94, 'Fordham South', 1, 2),
    (95, 'Forest Hills', 6, 2),
    (96, 'Forest Park/Highland Park', 6, 2),
    (97, 'Fort Greene', 2, 2),
    (98, 'Fresh Meadows', 6, 2),
    (99, 'Freshkills Park', 7, 2),
    (100, 'Garment District', 4, 5),
    (101, 'Glen Oaks', 6, 2),
    (102, 'Glendale', 6, 2),
    (103, 'Governor''s Island/Ellis Island/Liberty Island', 4, 5),
    (104, 'Governor''s Island/Ellis Island/Liberty Island', 4, 5),
    (105, 'Governor''s Island/Ellis Island/Liberty Island', 4, 5),
    (106, 'Gowanus', 2, 2),
    (107, 'Gramercy', 4, 5),
    (108, 'Gravesend', 2, 2),
    (109, 'Great Kills', 7, 2),
    (110, 'Great Kills Park', 7, 2),
    (111, 'Green-Wood Cemetery', 2, 2),
    (112, 'Greenpoint', 2, 2),
    (113, 'Greenwich Village North', 4, 5),
    (114, 'Greenwich Village South', 4, 5),
    (115, 'Grymes Hill/Clifton', 7, 2),
    (116, 'Hamilton Heights', 4, 2),
    (117, 'Hammels/Arverne', 6, 2),
    (118, 'Heartland Village/Todt Hill', 7, 2),
    (119, 'Highbridge', 1, 2),
    (120, 'Highbridge Park', 4, 2),
    (121, 'Hillcrest/Pomonok', 6, 2),
    (122, 'Hollis', 6, 2),
    (123, 'Homecrest', 2, 2),
    (124, 'Howard Beach', 6, 2),
    (125, 'Hudson Sq', 4, 5),
    (126, 'Hunts Point', 1, 2),
    (127, 'Inwood', 4, 2),
    (128, 'Inwood Hill Park', 4, 2),
    (129, 'Jackson Heights', 6, 2),
    (130, 'Jamaica', 6, 2),
    (131, 'Jamaica Estates', 6, 2),
    (132, 'JFK Airport', 6, 1),
    (133, 'Kensington', 2, 2),
    (134, 'Kew Gardens', 6, 2),
    (135, 'Kew Gardens Hills', 6, 2),
    (136, 'Kingsbridge Heights', 1, 2),
    (137, 'Kips Bay', 4, 5),
    (138, 'LaGuardia Airport', 6, 1),
    (139, 'Laurelton', 6, 2),
    (140, 'Lenox Hill East', 4, 5),
    (141, 'Lenox Hill West', 4, 5),
    (142, 'Lincoln Square East', 4, 5),
    (143, 'Lincoln Square West', 4, 5),
    (144, 'Little Italy/NoLiTa', 4, 5),
    (145, 'Long Island City/Hunters Point', 6, 2),
    (146, 'Long Island City/Queens Plaza', 6, 2),
    (147, 'Longwood', 1, 2),
    (148, 'Lower East Side', 4, 5),
    (149, 'Madison', 2, 2),
    (150, 'Manhattan Beach', 2, 2),
    (151, 'Manhattan Valley', 4, 5),
    (152, 'Manhattanville', 4, 2),
    (153, 'Marble Hill', 4, 2),
    (154, 'Marine Park/Floyd Bennett Field', 2, 2),
    (155, 'Marine Park/Mill Basin', 2, 2),
    (156, 'Mariners Harbor', 7, 2),
    (157, 'Maspeth', 6, 2),
    (158, 'Meatpacking/West Village West', 4, 5),
    (159, 'Melrose South', 1, 2),
    (160, 'Middle Village', 6, 2),
    (161, 'Midtown Center', 4, 5),
    (162, 'Midtown East', 4, 5),
    (163, 'Midtown North', 4, 5),
    (164, 'Midtown South', 4, 5),
    (165, 'Midwood', 2, 2),
    (166, 'Morningside Heights', 4, 2),
    (167, 'Morrisania/Melrose', 1, 2),
    (168, 'Mott Haven/Port Morris', 1, 2),
    (169, 'Mount Hope', 1, 2),
    (170, 'Murray Hill', 4, 5),
    (171, 'Murray Hill-Queens', 6, 2),
    (172, 'New Dorp/Midland Beach', 7, 2),
    (173, 'North Corona', 6, 2),
    (174, 'Norwood', 1, 2),
    (175, 'Oakland Gardens', 6, 2),
    (176, 'Oakwood', 7, 2),
    (177, 'Ocean Hill', 2, 2),
    (178, 'Ocean Parkway South', 2, 2),
    (179, 'Old Astoria', 6, 2),
    (180, 'Ozone Park', 6, 2),
    (181, 'Park Slope', 2, 2),
    (182, 'Parkchester', 1, 2),
    (183, 'Pelham Bay', 1, 2),
    (184, 'Pelham Bay Park', 1, 2),
    (185, 'Pelham Parkway', 1, 2),
    (186, 'Penn Station/Madison Sq West', 4, 5),
    (187, 'Port Richmond', 7, 2),
    (188, 'Prospect-Lefferts Gardens', 2, 2),
    (189, 'Prospect Heights', 2, 2),
    (190, 'Prospect Park', 2, 2),
    (191, 'Queens Village', 6, 2),
    (192, 'Queensboro Hill', 6, 2),
    (193, 'Queensbridge/Ravenswood', 6, 2),
    (194, 'Randalls Island', 4, 5),
    (195, 'Red Hook', 2, 2),
    (196, 'Rego Park', 6, 2),
    (197, 'Richmond Hill', 6, 2),
    (198, 'Ridgewood', 6, 2),
    (199, 'Rikers Island', 1, 2),
    (200, 'Riverdale/North Riverdale/Fieldston', 1, 2),
    (201, 'Rockaway Park', 6, 2),
    (202, 'Roosevelt Island', 4, 2),
    (203, 'Rosedale', 6, 2),
    (204, 'Rossville/Woodrow', 7, 2),
    (205, 'Saint Albans', 6, 2),
    (206, 'Saint George/New Brighton', 7, 2),
    (207, 'Saint Michaels Cemetery/Woodside', 6, 2),
    (208, 'Schuylerville/Edgewater Park', 1, 2),
    (209, 'Seaport', 4, 5),
    (210, 'Sheepshead Bay', 2, 2),
    (211, 'SoHo', 4, 5),
    (212, 'Soundview/Bruckner', 1, 2),
    (213, 'Soundview/Castle Hill', 1, 2),
    (214, 'South Beach/Dongan Hills', 7, 2),
    (215, 'South Jamaica', 6, 2),
    (216, 'South Ozone Park', 6, 2),
    (217, 'South Williamsburg', 2, 2),
    (218, 'Springfield Gardens North', 6, 2),
    (219, 'Springfield Gardens South', 6, 2),
    (220, 'Spuyten Duyvil/Kingsbridge', 1, 2),
    (221, 'Stapleton', 7, 2),
    (222, 'Starrett City', 2, 2),
    (223, 'Steinway', 6, 2),
    (224, 'Stuy Town/Peter Cooper Village', 4, 5),
    (225, 'Stuyvesant Heights', 2, 2),
    (226, 'Sunnyside', 6, 2),
    (227, 'Sunset Park East', 2, 2),
    (228, 'Sunset Park West', 2, 2),
    (229, 'Sutton Place/Turtle Bay North', 4, 5),
    (230, 'Times Sq/Theatre District', 4, 5),
    (231, 'TriBeCa/Civic Center', 4, 5),
    (232, 'Two Bridges/Seward Park', 4, 5),
    (233, 'UN/Turtle Bay South', 4, 5),
    (234, 'Union Sq', 4, 5),
    (235, 'University Heights/Morris Heights', 1, 2),
    (236, 'Upper East Side North', 4, 5),
    (237, 'Upper East Side South', 4, 5),
    (238, 'Upper West Side North', 4, 5),
    (239, 'Upper West Side South', 4, 5),
    (240, 'Van Cortlandt Park', 1, 2),
    (241, 'Van Cortlandt Village', 1, 2),
    (242, 'Van Nest/Morris Park', 1, 2),
    (243, 'Washington Heights North', 4, 2),
    (244, 'Washington Heights South', 4, 2),
    (245, 'West Brighton', 7, 2),
    (246, 'West Chelsea/Hudson Yards', 4, 5),
    (247, 'West Concourse', 1, 2),
    (248, 'West Farms/Bronx River', 1, 2),
    (249, 'West Village', 4, 5),
    (250, 'Westchester Village/Unionport', 1, 2),
    (251, 'Westerleigh', 7, 2),
    (252, 'Whitestone', 6, 2),
    (253, 'Willets Point', 6, 2),
    (254, 'Williamsbridge/Olinville', 1, 2),
    (255, 'Williamsburg (North Side)', 2, 2),
    (256, 'Williamsburg (South Side)', 2, 2),
    (257, 'Windsor Terrace', 2, 2),
    (258, 'Woodhaven', 6, 2),
    (259, 'Woodlawn/Wakefield', 1, 2),
    (260, 'Woodside', 6, 2),
    (261, 'World Trade Center', 4, 5),
    (262, 'Yorkville East', 4, 5),
    (263, 'Yorkville West', 4, 5),
    (264, 'Unknown', 8, 4),
    (265, 'Outside of NYC', 5, 4)
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 6. PERIODOS MENSUALES ANALIZADOS
-- ============================================================================

INSERT INTO core.periodo_mensual (mes_fuente, creado_at) VALUES
    ('2026-01-01', '2026-06-01 00:00:00+00'::TIMESTAMPTZ),
    ('2026-02-01', '2026-06-01 00:00:00+00'::TIMESTAMPTZ),
    ('2026-03-01', '2026-06-01 00:00:00+00'::TIMESTAMPTZ),
    ('2026-04-01', '2026-06-01 00:00:00+00'::TIMESTAMPTZ),
    ('2026-05-01', '2026-06-01 00:00:00+00'::TIMESTAMPTZ)
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 7. REGLAS DE CALIDAD
--
-- Las reglas de rechazo impiden la carga del registro. Las advertencias
-- conservan el viaje y registran la incidencia para su análisis.
-- ============================================================================

INSERT INTO core.regla_calidad (codigo, descripcion, severidad) VALUES
    ('PLATAFORMA_INVALIDA',
     'Licencia HVFHV ausente o fuera del conjunto conocido.', 'RECHAZO'),
    ('TIEMPO_INVALIDO',
     'Recogida o fin ausentes, o fin anterior a la recogida.', 'RECHAZO'),
    ('ZONA_INVALIDA',
     'Zona de origen o destino fuera del catálogo TLC.', 'RECHAZO'),
    ('DISTANCIA_DURACION_INVALIDA',
     'Millas negativas o duración no positiva.', 'RECHAZO'),
    ('ORIGEN_FUERA_MES',
     'Recogida fuera del mes de publicación del archivo.', 'RECHAZO'),
    ('SOLICITUD_POSTERIOR',
     'Solicitud posterior a la recogida; el viaje se conserva.', 'ADVERTENCIA')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 8. LOTES DE INGESTA
--
-- Cada registro resume el archivo procesado, su integridad, el número de filas
-- examinadas y el resultado final de la carga.
-- ============================================================================

INSERT INTO core.lote_ingesta
    (mes_fuente, archivo, sha256, filas_archivo, filas_procesadas,
     filas_cargadas, filas_rechazadas, estado, tamano_bloque, actualizado_at)
VALUES
    ('2026-01-01', 'fhvhv_tripdata_2026-01.parquet',
     'd7cdc852912fd7864166448a93cb40d7d6b09f136057b10ae31e9bb53d59c6f2',
     20940373, 1000000, 999967, 33, 'COMPLETO', 25000,
     '2026-06-01 00:05:00+00'::TIMESTAMPTZ),

    ('2026-02-01', 'fhvhv_tripdata_2026-02.parquet',
     '7f3c6737ed9a65884c9867ac2b8e05e358e56b42ecaf6d43f8009d40a9fce5c2',
     19875686, 1000000, 999990, 10, 'COMPLETO', 25000,
     '2026-06-01 00:05:00+00'::TIMESTAMPTZ),

    ('2026-03-01', 'fhvhv_tripdata_2026-03.parquet',
     '0f63d67cb9253b5a818cc4a1b2ddaf3a79955a6bf31c7577c53ff97fa040a262',
     22058358, 1000000, 999979, 21, 'COMPLETO', 25000,
     '2026-06-01 00:05:00+00'::TIMESTAMPTZ),

    ('2026-04-01', 'fhvhv_tripdata_2026-04.parquet',
     '15525aea9f82d55b885c6053414054e63f4c9abb3cdc44d78120a77d3aecc92b',
     20995953, 1000000, 999999, 1, 'COMPLETO', 25000,
     '2026-06-01 00:05:00+00'::TIMESTAMPTZ),

    ('2026-05-01', 'fhvhv_tripdata_2026-05.parquet',
     'e2b633a5be2280da537b4138f5bcb198eb04a6d3c2ef6bf7bd647f5b2c995287',
     22125744, 1000000, 999996, 4, 'COMPLETO', 25000,
     '2026-06-01 00:05:00+00'::TIMESTAMPTZ)

ON CONFLICT (mes_fuente) DO UPDATE SET
    archivo = EXCLUDED.archivo,
    sha256 = EXCLUDED.sha256,
    filas_archivo = EXCLUDED.filas_archivo,
    filas_procesadas = EXCLUDED.filas_procesadas,
    filas_cargadas = EXCLUDED.filas_cargadas,
    filas_rechazadas = EXCLUDED.filas_rechazadas,
    estado = EXCLUDED.estado,
    tamano_bloque = EXCLUDED.tamano_bloque,
    actualizado_at = EXCLUDED.actualizado_at;


-- ============================================================================
-- 9. CARGA DE VIAJES E INCIDENCIAS DESDE ARCHIVOS CSV
--
-- La importación se realiza manualmente en pgAdmin, un archivo por mes.
--
-- Configuración de importación:
--     Formato: CSV
--     Encabezado: Sí
--     Delimitador: coma
--     Carácter de cita: comillas dobles
--     Cadena NULL: campo vacío
--     Codificación: UTF-8
--
-- Archivos de viajes:
--     datos/viaje_2026_01.csv hasta datos/viaje_2026_05.csv
--     Tabla de destino: core.viaje
--     Número de columnas: 27
--
-- Archivos de incidencias:
--     datos/incidencia_2026_01.csv hasta incidencia_2026_05.csv
--     Tabla de destino: auditoria.incidencia
--     Número de columnas: 5
--
-- La columna mes_fuente se encuentra en cada CSV. PostgreSQL utiliza su valor
-- para dirigir automáticamente cada viaje hacia la partición mensual.
--
-- Los archivos usan el campo vacío para los importes nulos (tarifa_base y
-- pago_conductor). Por eso la cadena NULL de la importación debe quedar vacía:
-- si se escribe \N, ningún campo coincide con el marcador y los importes
-- vacíos se intentan convertir a NUMERIC, lo que interrumpe la carga.
-- ============================================================================


-- ============================================================================
-- 10. AGREGADO HORARIO
--
-- Ejecutar esta sección después de importar todos los registros en core.viaje.
-- El agregado resume el número de viajes por mes, hora, zona y plataforma.
-- ============================================================================

INSERT INTO analytics.demanda_hora
    (mes_fuente, hora, zona_origen_id, plataforma_codigo, viajes)
SELECT mes_fuente, DATE_TRUNC('hour', recogida_at) AS hora,
       zona_origen_id, plataforma_codigo, COUNT(*)::BIGINT AS viajes
FROM core.viaje
GROUP BY mes_fuente, DATE_TRUNC('hour', recogida_at),
         zona_origen_id, plataforma_codigo
ON CONFLICT (mes_fuente, hora, zona_origen_id, plataforma_codigo)
DO UPDATE SET viajes = EXCLUDED.viajes;


-- ============================================================================
-- 11. VERIFICACIÓN DE LOTES
--
-- La consulta presenta el estado de cada lote y permite contrastar las filas
-- cargadas y rechazadas durante el proceso de ingesta.
-- ============================================================================

SELECT mes_fuente, filas_archivo, filas_cargadas, filas_rechazadas, estado
FROM core.lote_ingesta
ORDER BY mes_fuente;


-- ============================================================================
-- 12. VERIFICACIÓN DE CATÁLOGOS Y TABLAS DE CONTROL
--
-- La consulta muestra la cantidad de registros almacenados en cada catálogo.
-- ============================================================================

SELECT 'plataforma' AS catalogo, COUNT(*) AS filas FROM core.plataforma
UNION ALL SELECT 'base_operativa', COUNT(*) FROM core.base_operativa
UNION ALL SELECT 'borough', COUNT(*) FROM core.borough
UNION ALL SELECT 'zona_servicio', COUNT(*) FROM core.zona_servicio
UNION ALL SELECT 'zona_taxi', COUNT(*) FROM core.zona_taxi
UNION ALL SELECT 'periodo_mensual', COUNT(*) FROM core.periodo_mensual
UNION ALL SELECT 'regla_calidad', COUNT(*) FROM core.regla_calidad
UNION ALL SELECT 'lote_ingesta', COUNT(*) FROM core.lote_ingesta
ORDER BY catalogo;