#!/bin/bash
# scripts/containerManagement/start-container.sh

set -euo pipefail

NAMESPACE="recipe-db"
CONFIG_DIR="k8s"
SECRET_NAME="postgres-secret"
PASSWORD_ENV_VAR="POSTGRES_PASSWORD"
MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MOUNT_PORT=8787
MOUNT_CMD="minikube mount ${LOCAL_PATH}:${MOUNT_PATH} --port=${MOUNT_PORT}"

# Utility function for printing section separators
print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

print_separator
echo "🔄 Checking if Minikube is running..."
print_separator

if ! minikube status >/dev/null 2>&1; then
  echo "🚀 Starting Minikube..."
  minikube start
else
  echo "✅ Minikube is already running."
fi

print_separator
echo "📂 Ensuring namespace '${NAMESPACE}' exists..."
print_separator

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

print_separator
echo "🔧 Loading environment variables from .env file (if present)..."
print_separator

if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
fi

print_separator
echo "⚙️ Creating/Updating ConfigMap from env..."
print_separator

envsubst < "${CONFIG_DIR}/configmap-template.yaml" | kubectl apply -f -

print_separator
echo "🔐 Creating/updating Secret..."
print_separator

if [ -z "${!PASSWORD_ENV_VAR:-}" ]; then
  read -r -s -p "Enter PostgreSQL password: " POSTGRES_PASSWORD
  echo
else
  POSTGRES_PASSWORD="${!PASSWORD_ENV_VAR}"
fi

kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" --ignore-not-found
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -n "$NAMESPACE"

print_separator
echo "💾 Applying PersistentVolumeClaim..."
print_separator

kubectl apply -f "${CONFIG_DIR}/pvc.yaml"

print_separator
echo "📦 Deploying PostgreSQL container..."
print_separator

kubectl apply -f "${CONFIG_DIR}/deployment.yaml"

print_separator
echo "🌐 Exposing PostgreSQL via ClusterIP Service..."
print_separator

kubectl apply -f "${CONFIG_DIR}/service.yaml"

print_separator
echo "⏳ Waiting for PostgreSQL pod to be ready..."
print_separator

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app=postgres \
  --timeout=90s

print_separator
echo "✅ PostgreSQL is up and running in namespace '$NAMESPACE'."
print_separator

if ! pgrep -f "$MOUNT_CMD" > /dev/null; then
  echo "🔗 Starting Minikube mount on port ${MOUNT_PORT}..."
  nohup minikube mount "${LOCAL_PATH}:${MOUNT_PATH}" --port="${MOUNT_PORT}" > /tmp/minikube-mount.log 2>&1 &
  echo "⏳ Waiting for Minikube mount to be ready..."
  sleep 5
else
  echo "✅ Minikube mount already running on port ${MOUNT_PORT}."
fi

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath="{.items[0].metadata.name}")

print_separator
echo "📡 Access info:"
echo "  Pod: $POD_NAME"
echo "  Host: postgres.$NAMESPACE.svc.cluster.local"
echo "  Port: 5432"
echo "  User: $POSTGRES_USER"
echo "  DB:   $POSTGRES_DB"
print_separator
