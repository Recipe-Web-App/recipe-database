#!/bin/bash
set -e

NAMESPACE="recipe-db"

echo "⏹️ Stopping PostgreSQL deployment in namespace: $NAMESPACE"

kubectl delete deployment postgres-deployment -n $NAMESPACE --ignore-not-found
kubectl delete service postgres-service -n $NAMESPACE --ignore-not-found

read -rp "Do you want to stop minikube? (y/N) " STOP_MINIKUBE
if [[ "$STOP_MINIKUBE" =~ ^[Yy]$ ]]; then
  echo "🛑 Stopping minikube..."
  minikube stop
fi

read -rp "Do you want to stop kubectl proxy? (y/N) " STOP_PROXY
if [[ "$STOP_PROXY" =~ ^[Yy]$ ]]; then
  PROXY_PID=$(pgrep -f "kubectl proxy" || true)
  if [[ -n "$PROXY_PID" ]]; then
    echo "🛑 Stopping kubectl proxy (PID $PROXY_PID)..."
    kill "$PROXY_PID"
  else
    echo "kubectl proxy is not running."
  fi
fi

echo "🛑 PostgreSQL deployment stopped. PVC and other resources remain intact."
