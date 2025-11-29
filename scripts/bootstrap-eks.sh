#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
CLUSTER_NAME="techxus-eks"
AWS_REGION="us-east-2"
NODE_TYPE="t3.medium"
NODE_COUNT=2

echo ">>> Creating EKS cluster: $CLUSTER_NAME in $AWS_REGION"

eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --with-oidc \
  --managed \
  --nodes "$NODE_COUNT" \
  --node-type "$NODE_TYPE"

echo ">>> Cluster created. Verifying kubectl context..."
kubectl get nodes

# === Install ArgoCD ===
echo ">>> Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ">>> Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd

# === Install Prometheus + Grafana (metrics only) ===
echo ">>> Creating monitoring namespace..."
kubectl create namespace monitoring || true

echo ">>> Adding Helm repo for kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat > metrics-values.yaml << 'EOF'
grafana:
  adminUser: admin
  adminPassword: admin123
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: false

prometheus:
  service:
    type: ClusterIP
EOF

echo ">>> Installing kube-prometheus-stack..."
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f metrics-values.yaml

echo ">>> Waiting for Grafana pod to be ready..."
kubectl rollout status deployment/monitoring-grafana -n monitoring

echo ">>> Basic monitoring stack installed."

echo ">>> Next steps (manual):"
echo "  1) Port-forward Grafana:"
echo "       kubectl port-forward -n monitoring svc/monitoring-grafana 8080:80"
echo "     and open http://localhost:8080 (admin / admin123)."
echo ""
echo "  2) Re-apply your ArgoCD Applications (api-gateway, hello-api) that point to techxus-gitops:"
echo "       kubectl apply -f api-gateway-app.yaml"
echo "       kubectl apply -f hello-api-app.yaml"
echo ""
echo "  3) Once ArgoCD syncs, your gateway + hello-api will be redeployed."
echo ""
echo ">>> Bootstrap complete."
