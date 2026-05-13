#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# PostgreSQL Init Script - DevOps Platform
# ═══════════════════════════════════════════════════════════════════════════════
# Cria bancos de dados adicionais na inicialização do container.
# O banco principal (devops_db) é criado automaticamente pelo POSTGRES_DB.
#
# Bancos criados por este script:
#   - devops_keycloak: Para o Keycloak (Identity & Access Management)
# ═══════════════════════════════════════════════════════════════════════════════
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE DATABASE devops_keycloak;
  GRANT ALL PRIVILEGES ON DATABASE devops_keycloak TO "$POSTGRES_USER";
EOSQL

echo "✅ Databases created: devops_keycloak"
