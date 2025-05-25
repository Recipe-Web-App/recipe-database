#!/bin/bash

export PGPASSWORD="$POSTGRES_PASSWORD"

echo "🔧 Initializing schema..."
for f in /sql/init/schema/*.sql; do
  echo "⏳ Executing $f"
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo "🔧 Loading functions..."
for f in /sql/init/functions/*.sql; do
  echo "⏳ Executing $f"
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo "🔧 Creating triggers..."
for f in /sql/init/triggers/*.sql; do
  echo "⏳ Executing $f"
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo "🔧 Creating views..."
for f in /sql/init/views/*.sql; do
  echo "⏳ Executing $f"
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo "✅ Database initialization complete."
