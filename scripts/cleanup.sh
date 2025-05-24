#!/bin/bash

NAMESPACE="recipe-db"

echo "Checking minikube status..."

if ! minikube status >/dev/null 2>&1; then
  echo "Minikube is not running. Starting minikube..."
  if ! minikube start; then
    echo "Failed to start minikube. Exiting."
    exit 1
  fi
else
  echo "Minikube is already running."
fi

echo "Deleting Kubernetes resources in namespace '$NAMESPACE'..."

kubectl delete -f k8s/configmap-template.yaml -n $NAMESPACE --ignore-not-found
kubectl delete -f k8s/deployment.yaml -n $NAMESPACE --ignore-not-found
kubectl delete -f k8s/secret.yaml -n $NAMESPACE --ignore-not-found
kubectl delete -f k8s/service.yaml -n $NAMESPACE --ignore-not-found

# PVC prompt for deletion
read -r -p "Do you want to delete the PersistentVolumeClaim (PVC)? This will delete all stored database data! (y/N): " del_pvc
if [[ "$del_pvc" =~ ^[Yy]$ ]]; then
  kubectl delete -f k8s/pvc.yaml -n $NAMESPACE --ignore-not-found
  echo "PVC deleted."
else
  echo "PVC retained."
fi

# Prompt to stop minikube
read -r -p "Do you want to stop (shut down) minikube now? (y/N): " stop_mk
if [[ "$stop_mk" =~ ^[Yy]$ ]]; then
  echo "Stopping minikube..."
  minikube stop
  echo "Minikube stopped."
else
  echo "Minikube left running."
fi

echo "Cleanup complete."
