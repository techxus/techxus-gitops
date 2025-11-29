#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
CLUSTER_NAME="techxus-eks"
AWS_REGION="us-east-2"

echo ">>> Using cluster: $CLUSTER_NAME in region: $AWS_REGION"
echo ">>> Make sure AWS_PROFILE / credentials are set correctly."
read -p "Continue with teardown? THIS WILL DELETE THE CLUSTER. (yes/no): " ANSWER
if [[ "$ANSWER" != "yes" ]]; then
  echo "Aborting."
  exit 0
fi

echo ">>> Deleting application namespaces (if they exist)..."
for NS in gateway hello monitoring logging tracing argocd; do
  if kubectl get ns "$NS" >/dev/null 2>&1; then
    echo "  - Deleting namespace: $NS"
    kubectl delete namespace "$NS" --wait=true
  else
    echo "  - Namespace $NS not found, skipping."
  fi
done

echo ">>> Deleting any remaining LoadBalancer Services (to clean up ELBs)..."
kubectl get svc -A --field-selector spec.type=LoadBalancer || true

echo ">>> If you see services above and want to delete them, do it now in another terminal,"
echo ">>> then press ENTER to continue."
read -r

echo ">>> Deleting EKS cluster with eksctl..."
eksctl delete cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo ">>> EKS cluster delete command issued."

echo ">>> NOTE: eksctl usually cleans up VPC, subnets, nodegroups, security groups, etc."
echo ">>> Still, log into AWS console and verify:"
echo "    - No leftover Load Balancers in EC2 -> Load Balancers"
echo "    - No leftover EBS volumes in EC2 -> Volumes"
echo "    - No leftover VPCs tagged with aws:eks:cluster-name = $CLUSTER_NAME"

echo ">>> Teardown complete (from script perspective)."
