#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# setup.sh - Bootstrap de la instancia (Ubuntu 22.04) para el proyecto TLC
# Instala Docker + Compose, levanta el stack y carga el modelo relacional.
# Ejecutar: bash setup.sh
# ============================================================================

echo "[1/5] Instalando dependencias del sistema..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

echo "[2/5] Agregando repositorio oficial de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[3/5] Instalando Docker Engine + Compose plugin..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[4/5] Agregando el usuario actual al grupo docker..."
sudo usermod -aG docker "${USER}"

echo "[5/5] Preparando variables de entorno..."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "  -> .env creado desde .env.example. EDITA la contraseña antes de continuar."
fi

echo
echo "Listo. Ahora:"
echo "  1) newgrp docker               (o cierra sesión y vuelve a entrar)"
echo "  2) docker compose up -d --build"
echo "  3) Para cargar el modelo: psql -h localhost -U tlc -d tlc -f ../Parte 1/Sql/01_schema.sql"
