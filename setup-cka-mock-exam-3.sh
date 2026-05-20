#!/bin/bash
# ============================================================
# CKA Mock Exam 3 - Environment Setup Script
# Based on: real 2025/2026 CKA exam reports (post-Feb 2025 curriculum)
# Covers: Gateway API, Helm, PriorityClass, sidecar, CNI,
#         kube-apiserver troubleshooting, StorageClass, PDB
# Target: Vagrant cluster (cp, node01, node02)
# Run: ssh cp && ./setup-cka-mock-exam-3.sh
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
hdr()  { echo -e "\n${CYAN}================================================${NC}"; \
         echo -e "${CYAN}  $1${NC}"; \
         echo -e "${CYAN}================================================${NC}"; }

# ---- Pre-flight -----------------------------------------------
hdr "Pre-flight"

if [[ -z "$KUBECONFIG" ]]; then
  INVOKING_USER="${SUDO_USER:-$USER}"
  for candidate in "/home/${INVOKING_USER}/.kube/config" \
                   "/root/.kube/config" "/etc/kubernetes/admin.conf"; do
    if [[ -f "$candidate" ]]; then
      export KUBECONFIG="$candidate"; log "KUBECONFIG=$KUBECONFIG"; break
    fi
  done
fi

if ! kubectl get nodes &>/dev/null; then
  err "kubectl cannot reach cluster. Tried KUBECONFIG=${KUBECONFIG:-<not set>}"
  exit 1
fi

log "Nodes:"; kubectl get nodes --no-headers | awk '{print "  "$1" ("$2")"}'

sudo mkdir -p /opt/course
sudo chown $USER:$USER /opt/course
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
  mkdir -p /opt/course/$i
done
log "Created /opt/course/N directories"

# ---- Q1 | Helm install + template ----------------------------
hdr "Q1 | Helm install + template"

kubectl create namespace helm-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

# Ensure helm is available
if ! command -v helm &>/dev/null; then
  warn "Helm not found — installing helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash &>/dev/null
fi

# Add bitnami repo (needed for Q1)
helm repo add bitnami https://charts.bitnami.com/bitnami &>/dev/null || true
helm repo update &>/dev/null || true

log "Q1: helm + bitnami repo ready. Namespace helm-lab created."

# ---- Q2 | Gateway API + Ingress migration -------------------
hdr "Q2 | Gateway API - migrate Ingress to Gateway+HTTPRoute"

log "Q2: installing gateway api"

kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

kubectl create namespace gateway-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null


# Deploy a backend app + service
cat <<'EOF' | kubectl apply --validate=false -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-backend
  namespace: gateway-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-backend
  template:
    metadata:
      labels:
        app: web-backend
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: web-backend-svc
  namespace: gateway-lab
spec:
  selector:
    app: web-backend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: gateway-lab
spec:
  rules:
  - host: web.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-backend-svc
            port:
              number: 80
EOF

# TLS secret for the Gateway
kubectl -n gateway-lab create secret tls web-tls \
  --cert=/etc/kubernetes/pki/apiserver.crt \
  --key=/etc/kubernetes/pki/apiserver.key \
  --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

log "Q2: Ingress 'web-ingress', Deployment 'web-backend', Service 'web-backend-svc' in gateway-lab"
log "Q2: TLS secret 'web-tls' created in gateway-lab"

# ---- Q3 | PriorityClass + Deployment ------------------------
hdr "Q3 | PriorityClass"

kubectl create namespace priority-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

# Create an existing PriorityClass for reference
cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: background-tasks
value: 100
globalDefault: false
description: "Low priority for background workloads"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: priority-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
EOF
log "Q3: PriorityClass 'background-tasks' (value=100) and Deployment 'api-server' in priority-lab"

# ---- Q4 | Sidecar log container ------------------------------
hdr "Q4 | Sidecar log container"

kubectl create namespace logging-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-logger
  namespace: logging-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-logger
  template:
    metadata:
      labels:
        app: app-logger
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        command:
        - sh
        - -c
        - while true;do date >> /var/log/nginx/access.log;sleep 1;done
        # No log sidecar yet — that's the task
EOF
log "Q4: Deployment 'app-logger' in logging-lab (no sidecar yet — your task)"

# ---- Q5 | ConfigMap + nginx TLS config ---------------------
hdr "Q5 | ConfigMap nginx TLS"

kubectl create namespace nginx-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: nginx-lab
data:
  nginx.conf: |
    server {
      listen 443 ssl;
      ssl_protocols TLSv1.3;
      ssl_certificate /etc/nginx/tls/tls.crt;
      ssl_certificate_key /etc/nginx/tls/tls.key;
      location / {
        return 200 'OK';
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-tls
  namespace: nginx-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-tls
  template:
    metadata:
      labels:
        app: nginx-tls
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
        - name: tls
          mountPath: /etc/nginx/tls
      volumes:
      - name: config
        configMap:
          name: nginx-config
      - name: tls
        secret:
          secretName: web-tls
EOF
kubectl create secret tls web-tls -n nginx-lab \
  --cert=/etc/kubernetes/pki/apiserver.crt \
  --key=/etc/kubernetes/pki/apiserver.key \
  --dry-run=client -o yaml | kubectl apply -f -
log "Q5: ConfigMap 'nginx-config' with TLSv1.3 only in nginx-lab (task: also enable TLSv1.2)"

# ---- Q6 | Broken kube-apiserver (wrong etcd endpoint) ------
hdr "Q6 | Broken kube-apiserver"

# Save a backup of the working apiserver manifest
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /opt/course/6/kube-apiserver-backup.yaml
log "Q6: kube-apiserver manifest backed up to /opt/course/6/kube-apiserver-backup.yaml"
warn "Q6: To break the cluster for this question, run AFTER setup:"
warn "Q6:   sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver-orig.yaml"
warn "Q6:   sudo sed -i 's/--etcd-servers=https:\/\/127.0.0.1:2379/--etcd-servers=https:\/\/127.0.0.1:1234/' /etc/kubernetes/manifests/kube-apiserver.yaml"
warn "Q6:   Wait ~30s for apiserver to fail, then fix it during the exam"
warn "Q6: Fix: restore correct etcd endpoint in the manifest"

# ---- Q7 | CNI install (simulated missing CNI) --------------
hdr "Q7 | CNI identification + network policy"

kubectl create namespace netpol-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: netpol-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: netpol-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: netpol-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: backend-api-svc
  namespace: netpol-lab
spec:
  selector:
    app: backend-api
  ports:
  - port: 8080
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: cache-svc
  namespace: netpol-lab
spec:
  selector:
    app: cache
  ports:
  - port: 6379
    targetPort: 80
EOF
log "Q7: Deployments frontend/backend-api/cache in netpol-lab"

# ---- Q8 | StorageClass + dynamic PV + Pod ------------------
hdr "Q8 | StorageClass + dynamic PV"

kubectl create namespace storage-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# Pre-create a PV for the matching task
cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: PersistentVolume
metadata:
  name: existing-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/existing-data
  storageClassName: manual
EOF
log "Q8: PV 'existing-pv' (1Gi, RWO, manual storageClass) created"
log "Q8: Task: create matching PVC + create StorageClass 'fast-local' + pod using dynamic PVC"

# ---- Q9 | Pod Disruption Budget ------------------------------
hdr "Q9 | Pod Disruption Budget"

kubectl create namespace pdb-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
  namespace: pdb-lab
spec:
  replicas: 4
  selector:
    matchLabels:
      app: critical-app
  template:
    metadata:
      labels:
        app: critical-app
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
EOF
log "Q9: Deployment 'critical-app' (4 replicas) in pdb-lab"

# ---- Q10 | CronJob + Job inspection -------------------------
hdr "Q10 | CronJob"

kubectl create namespace batch-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
log "Q10: Namespace batch-lab ready"

# ---- Q11 | Troubleshoot broken Service ----------------------
hdr "Q11 | Broken Service (wrong selector + wrong port)"

kubectl create namespace trouble-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: trouble-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment
      tier: backend
  template:
    metadata:
      labels:
        app: payment
        tier: backend
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: payment-svc
  namespace: trouble-lab
spec:
  selector:
    app: payment
    tier: frontend        # WRONG: should be backend
  ports:
  - port: 8080
    targetPort: 9090      # WRONG: should be 80
EOF
log "Q11: Deployment 'payment-service' + broken Service 'payment-svc' in trouble-lab"
log "Q11: Bugs: wrong tier label in selector, wrong targetPort"

# ---- Q12 | RBAC - ClusterRole + aggregation -----------------
hdr "Q12 | RBAC ClusterRole aggregation"

kubectl create namespace rbac-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader-base
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-sa
  namespace: rbac-lab
EOF
log "Q12: ClusterRole 'pod-reader-base' with aggregation label, ServiceAccount 'monitoring-sa' in rbac-lab"

# ---- Q13 | Rollout + rollback + history ---------------------
hdr "Q13 | Deployment rollout + rollback"

kubectl create namespace rollout-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: rollout-lab
  annotations:
    kubernetes.io/change-cause: "Initial deploy - nginx:1.24-alpine"
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:1.24-alpine
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
EOF

# Give it a second rev
sleep 3
kubectl -n rollout-lab set image deployment/web-app web=nginx:1.25-alpine &>/dev/null
kubectl -n rollout-lab annotate deployment web-app kubernetes.io/change-cause="v2 - nginx:1.25-alpine" --overwrite &>/dev/null
sleep 2
kubectl -n rollout-lab set image deployment/web-app web=nginx:BROKEN-TAG &>/dev/null
kubectl -n rollout-lab annotate deployment web-app kubernetes.io/change-cause="v3 - broken tag" --overwrite &>/dev/null
log "Q13: Deployment 'web-app' in rollout-lab with 3 revisions, last one broken"

# ---- Q14 | init container + emptyDir -----------------------
hdr "Q14 | Init container"

kubectl create namespace init-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
log "Q14: Namespace init-lab ready"

# ---- Q15 | Node drain + PDB interaction ---------------------
hdr "Q15 | Node drain with PDB"

kubectl create namespace drain-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-app
  namespace: drain-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ha-app
  template:
    metadata:
      labels:
        app: ha-app
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ha-app-pdb
  namespace: drain-lab
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: ha-app
EOF
log "Q15: Deployment 'ha-app' (3 replicas) + PDB minAvailable=2 in drain-lab"

# ---- Q16 | Resource quota + LimitRange ---------------------
hdr "Q16 | ResourceQuota + LimitRange"

kubectl create namespace quota-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: quota-lab
spec:
  hard:
    pods: "5"
    requests.cpu: "1"
    requests.memory: 512Mi
    limits.cpu: "2"
    limits.memory: 1Gi
EOF
log "Q16: ResourceQuota 'compute-quota' in quota-lab"

# ---- Q17 | Helm + kustomize combined -----------------------
hdr "Q17 | Helm template save + Kustomize patch"

kubectl create namespace deploy-lab --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
mkdir -p /opt/course/17/app/base
mkdir -p /opt/course/17/app/prod

cat <<'EOF' > /opt/course/17/app/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
EOF

cat <<'EOF' > /opt/course/17/app/base/kustomization.yaml
resources:
- deployment.yaml
EOF

cat <<'EOF' > /opt/course/17/app/prod/kustomization.yaml
namespace: deploy-lab
resources:
- ../base
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: myapp
EOF
log "Q17: Kustomize overlay structure at /opt/course/17/app/"

# ---- Aliases ------------------------------------------------
hdr "Shell aliases"

grep -q "CKA Mock Exam 3" ~/.bashrc || cat >> ~/.bashrc << 'ALIASES'

# CKA Mock Exam 3 aliases
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
source <(kubectl completion bash)
complete -F __start_kubectl k
ALIASES

log "Aliases added to ~/.bashrc — run: source ~/.bashrc"

# ---- Summary ------------------------------------------------
hdr "Setup Complete!"

echo ""
echo -e "${GREEN}✔ Environment ready for CKA Mock Exam 3 (17 questions)${NC}"
echo ""
echo "Namespaces created:"
kubectl get ns --no-headers | grep -E 'lab$' | awk '{print "  - "$1}' 2>/dev/null || true
echo ""
echo "Nodes:"
kubectl get nodes --no-headers | awk '{print "  - "$1" ("$2")"}'
echo ""
echo -e "${YELLOW}Manual steps before starting:${NC}"
echo "  source ~/.bashrc"
echo ""
echo -e "${YELLOW}Q6 (break kube-apiserver) — run when ready to start the exam:${NC}"
echo "  sudo sed -i 's/--etcd-servers=https:\/\/127.0.0.1:2379/--etcd-servers=https:\/\/127.0.0.1:1234/' \\"
echo "    /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "  # Wait ~30s, verify: kubectl get nodes (should fail)"
echo ""
echo "Good luck! 🎯"
