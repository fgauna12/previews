#!/bin/bash

set -ex

echo "Creating cluster with base name $1 on $2"

if [ -z "$1" ]
  then
    echo "Please provide the name of the cluster."
    exit -1
fi

if [ -z "$2" ]
  then
    echo "Please provide the name of the resource group."
    exit -1
fi

CLUSTER_NAME="$1"
RESOURCE_GROUP_NAME="$2"
VNET_NAME="vnet-$CLUSTER_NAME"
IDENTITY_NAME="$CLUSTER_NAME-identity"

echo $'\n=== Creating resource group'
# Create the resource group
az group create \
    -n $RESOURCE_GROUP_NAME \
    -l eastus \
    --tags customer=Internal owner=facundo@boxboat.com

echo $'\n=== Creating virtual network'
# Create the virtual network and first subnet for AKS
az network vnet create \
    -n $VNET_NAME \
    -g $RESOURCE_GROUP_NAME \
    -l eastus \
    --subnet-name aks \
    --address-prefixes 10.0.0.0/16 \
    --subnet-prefixes 10.0.0.0/24

echo $'\n=== Creating managed identity'
# Create a managed identity
IDENTITY_RESULT=$(az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP_NAME)

PRINCIPAL_ID=$(echo $IDENTITY_RESULT | jq -r '.principalId')
IDENTITY_ID=$(echo $IDENTITY_RESULT | jq -r '.id')

echo $'\n=== Waiting for 1 minute'
sleep 1m

echo $'\n=== Granting \'Network Contributor\' role assignments to the managed identity'
# Grant network contributor role to the managed identity
az role assignment create --role "Network Contributor" --assignee $PRINCIPAL_ID  

AKS_SUBNET=$(az network vnet subnet show -g $RESOURCE_GROUP_NAME --vnet-name $VNET_NAME -n aks --query "id" -o tsv)

SYSTEM_NODE_POOL_NAME="system"

echo $'\n=== Creating AKS cluster'
az aks create -n $CLUSTER_NAME \
       -g $RESOURCE_GROUP_NAME \
       -l eastus \
       --network-plugin azure \
       --generate-ssh-keys \
       --vnet-subnet-id $AKS_SUBNET \
       --enable-managed-identity \
       --assign-identity $IDENTITY_ID \
       --dns-service-ip 10.1.0.10 \
       --service-cidr 10.1.0.0/24 \
       --tags "ignore-cloud-nuke=yes" \
       --node-count 1 \
       --nodepool-name "$SYSTEM_NODE_POOL_NAME"
       
echo $'\n=== Adding user node pool'
az aks nodepool add \
    --resource-group $RESOURCE_GROUP_NAME \
    --cluster-name $CLUSTER_NAME \
    --name "usera" \
    --mode "User" \
    --node-count 2 \
    --node-vm-size "Standard_DS3_v2"

az aks get-credentials -n $CLUSTER_NAME -g $RESOURCE_GROUP_NAME

echo $'\n=== Tainting the system node pool'
kubectl taint node -l kubernetes.azure.com/agentpool=$SYSTEM_NODE_POOL_NAME CriticalAddonsOnly=true:NoSchedule

exit 0
