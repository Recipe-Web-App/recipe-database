#!/bin/bash

set -euo pipefail

NAMESPACE="recipe-db"
POD_LABEL="app=postgres"
LOCAL_PORT=5432

# Load .env vars into shell variables safely
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi

DB_USER=${DB_USER:-}
DB_NAME=${DB_NAME:-}
DB_PASSWORD=${DB_PASSWORD:-}

if [ -z "$DB_USER" ]; then
  read -rp "Enter DB user: " DB_USER
fi

if [ -z "$DB_NAME" ]; then
  read -rp "Enter DB name: " DB_NAME
fi

if [ -z "$DB_PASSWORD" ]; then
  read -s -rp "Enter DB password: " DB_PASSWORD
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

echo "🔐 Starting psql client..."

PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $LOCAL_PORT -U "$DB_USER" -d "$DB_NAME"

echo "🛑 Closing port-forward (PID $PF_PID)..."
kill $PF_PID
