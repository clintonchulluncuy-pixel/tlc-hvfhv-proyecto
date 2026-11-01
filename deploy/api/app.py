import os
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import psycopg2
import psycopg2.extras

DB_URL = os.getenv("DATABASE_URL", "postgresql://tlc:change_me@db:5432/tlc")

app = FastAPI(title="TLC Demand API")

app.mount("/static", StaticFiles(directory="static"), name="static")


def get_conn():
    return psycopg2.connect(DB_URL)


@app.get("/")
def index():
    return FileResponse("static/index.html")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/zones")
def zones():
    with get_conn() as conn:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("""
            SELECT z.location_id, z.nombre, b.nombre AS borough,
                   z.longitud, z.latitud
            FROM core.zona_taxi z
            JOIN core.borough b ON b.borough_id = z.borough_id
            WHERE z.longitud IS NOT NULL
            ORDER BY z.location_id
        """)
        return cur.fetchall()


@app.get("/api/forecast/{zone_id}")
def forecast(zone_id: int):
    with get_conn() as conn:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        cur.execute("""
            SELECT z.nombre AS zona, b.nombre AS borough
            FROM core.zona_taxi z
            JOIN core.borough b ON b.borough_id = z.borough_id
            WHERE z.location_id = %(z)s
        """, {"z": zone_id})
        info = cur.fetchone()
        if not info:
            raise HTTPException(404, "Zona no encontrada")

        cur.execute("""
            WITH ultima AS (
                SELECT max(hora) AS h FROM analytics.demanda_serie
            )
            SELECT p.codigo AS plataforma,
                   p.nombre AS nombre,
                   (SELECT viajes FROM analytics.demanda_serie
                    WHERE zona_origen_id = %(z)s AND plataforma_codigo = p.codigo
                      AND hora = (SELECT h FROM ultima) - INTERVAL '167 hours')
                        AS pronostico_naive,
                   (SELECT ROUND(AVG(viajes), 1) FROM analytics.demanda_serie
                    WHERE zona_origen_id = %(z)s AND plataforma_codigo = p.codigo
                      AND hora IN (
                          SELECT (SELECT h FROM ultima) - INTERVAL '167 hours'
                                 - (INTERVAL '168 hours' * g)
                          FROM generate_series(0, 3) AS g
                      )) AS pronostico_promedio,
                   (SELECT h FROM ultima) AS ultima,
                   (SELECT h FROM ultima) + INTERVAL '1 hour' AS objetivo
            FROM core.plataforma p
            ORDER BY p.codigo
        """, {"z": zone_id})
        pron = cur.fetchall()

        cur.execute("""
            SELECT to_char(hora, 'YYYY-MM-DD HH24:MI') AS hora,
                   plataforma_codigo, viajes
            FROM analytics.demanda_serie
            WHERE zona_origen_id = %(z)s
              AND hora >= (SELECT max(hora) - INTERVAL '72 hours'
                           FROM analytics.demanda_serie)
            ORDER BY hora
        """, {"z": zone_id})
        historico = cur.fetchall()

    return {"zona": info, "pronostico": pron, "historico": historico}


@app.get("/api/anomalies/{zone_id}")
def anomalies(zone_id: int, days: int = 30):
    with get_conn() as conn:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("""
            WITH stats AS (
                SELECT plataforma_codigo,
                       extract(hour from hora)::int AS hh,
                       extract(dow from hora)::int  AS dow,
                       avg(viajes) AS media,
                       stddev(viajes) AS sd
                FROM analytics.demanda_serie
                WHERE zona_origen_id = %(z)s
                GROUP BY 1, 2, 3
            ),
            serie AS (
                SELECT hora, plataforma_codigo, viajes,
                       extract(hour from hora)::int AS hh,
                       extract(dow from hora)::int  AS dow
                FROM analytics.demanda_serie
                WHERE zona_origen_id = %(z)s
                  AND hora >= (SELECT max(hora) - (%(d)s * INTERVAL '1 day')
                               FROM analytics.demanda_serie)
            )
            SELECT to_char(s.hora, 'YYYY-MM-DD HH24:MI') AS hora,
                   s.plataforma_codigo, s.viajes,
                   ROUND(st.media::numeric, 1) AS media,
                   ROUND(st.sd::numeric, 1) AS sd,
                   ROUND(((s.viajes - st.media) / NULLIF(st.sd, 0))::numeric, 2) AS zscore
            FROM serie s
            JOIN stats st
              ON st.plataforma_codigo = s.plataforma_codigo
             AND st.hh = s.hh AND st.dow = s.dow
            WHERE ABS((s.viajes - st.media) / NULLIF(st.sd, 0)) > 2
            ORDER BY s.hora DESC
            LIMIT 100
        """, {"z": zone_id, "d": days})
        return cur.fetchall()
