#!/bin/bash

set -euo pipefail

NAMESPACE="recipe-db"
POD_LABEL="app=postgres"
LOCAL_PORT=15432

# Load .env vars into shell variables safely
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi

POSTGRES_USER=${POSTGRES_USER:-}
POSTGRES_DB=${POSTGRES_DB:-}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}

if [ -z "$POSTGRES_USER" ]; then
  read -rp "Enter DB user: " POSTGRES_USER
fi

if [ -z "$POSTGRES_DB" ]; then
  read -rp "Enter DB name: " POSTGRES_DB
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
  read -s -rp "Enter DB password: " POSTGRES_PASSWORD
  echo
fi

echo "🚀 Finding PostgreSQL pod in namespace $NAMESPACE..."

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "❌ No PostgreSQL pod found in namespace $NAMESPACE with label $POD_LABEL"
  exit 1
fi

echo "🔌 Port-forwarding pod $POD_NAME to localhost:$LOCAL_PORT ..."
kubectl port-forward -n "$NAMESPACE" pod/"$POD_NAME" $LOCAL_PORT:5432 &
PF_PID=$!

sleep 3 # give port-forward time to start

echo "📂 Defaulting to schema: $POSTGRES_SCHEMA"
echo "🔐 Starting psql client..."

PGOPTIONS="--search_path=$POSTGRES_SCHEMA" \
  PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -h localhost -p $LOCAL_PORT -U "$POSTGRES_USER" -d "$POSTGRES_DB"


echo "🛑 Closing port-forward (PID $PF_PID)..."
kill $PF_PID
