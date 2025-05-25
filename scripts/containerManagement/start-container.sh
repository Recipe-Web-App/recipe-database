#!/bin/bash
set -euo pipefail

NAMESPACE="recipe-db"
CONFIG_DIR="k8s"
SECRET_NAME="postgres-secret"
PASSWORD_ENV_VAR="POSTGRES_PASSWORD"
MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MOUNT_PORT=8787

echo "🔄 Checking if Minikube is running..."
if ! minikube status >/dev/null 2>&1; then
  echo "🚀 Starting Minikube..."
  minikube start
else
  echo "✅ Minikube is already running."
fi

echo "📂 Ensuring namespace '${NAMESPACE}' exists..."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# Load environment variables
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
fi

echo "⚙️ Creating/Updating ConfigMap from env..."
envsubst < "${CONFIG_DIR}/configmap-template.yaml" | kubectl apply -f -

echo "🔐 Creating/updating Secret..."
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

echo "💾 Applying PersistentVolumeClaim..."
kubectl apply -f "${CONFIG_DIR}/pvc.yaml"

echo "📦 Deploying PostgreSQL container..."
kubectl apply -f "${CONFIG_DIR}/deployment.yaml"

echo "🌐 Exposing PostgreSQL via ClusterIP Service..."
kubectl apply -f "${CONFIG_DIR}/service.yaml"

echo "⏳ Waiting for PostgreSQL pod to be ready..."
kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app=postgres \
  --timeout=90s

echo "✅ PostgreSQL is up and running in namespace '$NAMESPACE'."

# Start Minikube mount in background if not already running
if ! pgrep -f "minikube mount ${LOCAL_PATH}:${MOUNT_PATH} --port=${MOUNT_PORT}" > /dev/null; then
  echo "🔗 Starting Minikube mount on port ${MOUNT_PORT}..."
  nohup minikube mount "${LOCAL_PATH}:${MOUNT_PATH}" --port="${MOUNT_PORT}" > /tmp/minikube-mount.log 2>&1 &
  echo "⏳ Waiting for Minikube mount to be ready..."
  sleep 5
else
  echo "✅ Minikube mount already running on port ${MOUNT_PORT}."
fi

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath="{.items[0].metadata.name}")

echo "📡 Access info:"
echo "  Pod: $POD_NAME"
echo "  Host: postgres.$NAMESPACE.svc.cluster.local"
echo "  Port: 5432"
echo "  User: $POSTGRES_USER"
echo "  DB:   $POSTGRES_DB"
