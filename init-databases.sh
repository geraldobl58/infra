#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# PostgreSQL Init Script - Nexo Platform
# ═══════════════════════════════════════════════════════════════════════════════
# Cria bancos de dados adicionais na inicialização do container.
# O banco principal (nexo_db) é criado automaticamente pelo POSTGRES_DB.
#
# Bancos criados por este script:
#   - nexo_keycloak: Para o Keycloak (Identity & Access Management)
# ═══════════════════════════════════════════════════════════════════════════════
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE DATABASE nexo_keycloak;
  GRANT ALL PRIVILEGES ON DATABASE nexo_keycloak TO "$POSTGRES_USER";
EOSQL

echo "✅ Databases created: nexo_keycloak"
