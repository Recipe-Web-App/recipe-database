#!/bin/bash
# scripts/containerManagement/deploy-container.sh

set -euo pipefail

NAMESPACE="recipe-database"
CONFIG_DIR="k8s"
SECRET_NAME="recipe-database-secret"
IMAGE_NAME="recipe-database"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🔧 Setting up Minikube environment..."
print_separator "-"
env_status=true
if ! command -v minikube >/dev/null 2>&1; then
  echo "❌ Minikube is not installed. Please install it first."
  env_status=false
else
  echo "✅ Minikube is installed."
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "❌ kubectl is not installed. Please install it first."
  env_status=false
else
  echo "✅ kubectl is installed."
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker is not installed. Please install it first."
  env_status=false
else
  echo "✅ Docker is installed."
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is not installed. Please install it first."
  env_status
else
  echo "✅ jq is installed."
fi
if ! $env_status; then
  echo "Please resolve the above issues before proceeding."
  exit 1
fi

if ! minikube status >/dev/null 2>&1; then
  print_separator "-"
  echo "🚀 Starting Minikube..."
  minikube start

  if ! minikube addons list | grep -q 'ingress *enabled'; then
    echo "🔌 Enabling Minikube ingress addon..."
    minikube addons enable ingress
    echo "✅ Minikube started."
  fi
else
  echo "✅ Minikube is already running."
fi

print_separator "="
echo "📂 Ensuring namespace '${NAMESPACE}' exists..."
print_separator "-"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "✅ '$NAMESPACE' namespace already exists."
else
  kubectl create namespace "$NAMESPACE"
  echo "✅ '$NAMESPACE' namespace created."
fi


print_separator "="
echo "🔧 Loading environment variables from .env file (if present)..."
print_separator "-"

if [ -f .env ]; then
  set -o allexport
  # Capture env before
  BEFORE_ENV=$(mktemp)
  AFTER_ENV=$(mktemp)
  env | cut -d= -f1 | sort > "$BEFORE_ENV"
  # shellcheck disable=SC1091
  source .env
  # Capture env after
  env | cut -d= -f1 | sort > "$AFTER_ENV"
  # Show newly loaded/changed variables
  echo "✅ Loaded variables from .env:"
  comm -13 "$BEFORE_ENV" "$AFTER_ENV"
  rm -f "$BEFORE_ENV" "$AFTER_ENV"
  set +o allexport
fi

print_separator "="
echo "🐳 Building Docker images (inside Minikube Docker daemon)"
print_separator '-'

eval "$(minikube docker-env)"

echo "📦 Building main database image..."
docker build --target database -t "$FULL_IMAGE_NAME" .
echo "✅ Database image '${FULL_IMAGE_NAME}' built successfully."

echo "📦 Building job runner image..."
docker build --target jobs -t "${IMAGE_NAME}-jobs:${IMAGE_TAG}" .
echo "✅ Job runner image '${IMAGE_NAME}-jobs:${IMAGE_TAG}' built successfully."

print_separator "="
echo "⚙️ Creating/Updating ConfigMap from env..."
print_separator "-"

envsubst < "${CONFIG_DIR}/configmap-template.yaml" | kubectl apply -f -

print_separator "="
echo "🔐 Creating/updating Secret..."
print_separator "-"

kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" --ignore-not-found
envsubst < "${CONFIG_DIR}/secret-template.yaml" | kubectl apply -f -

print_separator "="
echo "💾 Applying PersistentVolumeClaim..."
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/pvc.yaml"

kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace=="recipe-database") | .metadata.name' | \
  xargs -I{} kubectl label pv {} app=recipe-database --overwrite

print_separator "="
echo "📦 Deploying PostgreSQL container..."
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/deployment.yaml"

print_separator "="
echo "🌐 Exposing PostgreSQL via NodePort Service..."
print_separator "-"

envsubst < "${CONFIG_DIR}/service-template.yaml" | kubectl apply -f -

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app=recipe-database \
  --timeout=90s

print_separator "="
echo "✅ PostgreSQL is up and running in namespace '$NAMESPACE'."
print_separator "-"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "<node-ip>")
DB_HOSTNAME="recipe-database.local"

print_separator "="
echo "🌐 Updating /etc/hosts with $DB_HOSTNAME..."
print_separator "-"

# Remove existing entry if present, then add new one
sed -i "/$DB_HOSTNAME/d" /etc/hosts
echo "$MINIKUBE_IP $DB_HOSTNAME" >> /etc/hosts
echo "✅ Added: $MINIKUBE_IP $DB_HOSTNAME"

print_separator "="
echo "📡 Access info:"
echo "  Pod: $POD_NAME"
print_separator "-"
echo "  Internal (cluster) access:"
echo "    Host: recipe-database-service.$NAMESPACE.svc.cluster.local"
echo "    Port: 5432"
print_separator "-"
echo "  External (NodePort) access:"
echo "    Host: $DB_HOSTNAME ($MINIKUBE_IP)"
echo "    Port: $NODEPORT_POSTGRES"
echo "    Connection: psql -h $DB_HOSTNAME -p $NODEPORT_POSTGRES -U $DB_MAINT_USER -d $POSTGRES_DB"
print_separator "-"
echo "  Credentials:"
echo "    User: $DB_MAINT_USER"
echo "    DB:   $POSTGRES_DB"
print_separator "="
