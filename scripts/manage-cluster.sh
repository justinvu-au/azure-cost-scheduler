#!/usr/bin/env bash
set -euo pipefail

ACTION="$1"          # start | stop | status
RESOURCE_GROUP="$2"
CLUSTER_NAME="$3"

if [[ "$ACTION" != "start" && "$ACTION" != "stop" && "$ACTION" != "status" ]]; then
  echo "Usage: manage-cluster.sh <start|stop|status> <resource-group> <cluster-name>"
  exit 1
fi

if [[ "$ACTION" == "status" ]]; then
  STATE=$(az aks show \
    --name "$CLUSTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "powerState.code" -o tsv)
  echo "${CLUSTER_NAME}: ${STATE}"
  exit 0
fi

CURRENT_STATE=$(az aks show \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "powerState.code" -o tsv)

if [[ "$ACTION" == "stop" && "$CURRENT_STATE" == "Stopped" ]]; then
  echo "${CLUSTER_NAME} is already stopped — skipping."
  exit 0
fi

if [[ "$ACTION" == "start" && "$CURRENT_STATE" == "Running" ]]; then
  echo "${CLUSTER_NAME} is already running — skipping."
  exit 0
fi

echo "Running: az aks ${ACTION} --name ${CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}"
az aks "$ACTION" --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP"
echo "${CLUSTER_NAME}: ${ACTION} completed"