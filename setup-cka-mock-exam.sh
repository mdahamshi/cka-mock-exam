#!/bin/bash
# ============================================================
# CKA Mock Exam - Environment Setup Script
# Target: Vagrant cluster (cp, node01, node02)
# Run this from the control-plane node: ssh cp
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
hdr()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Pre-flight ────────────────────────────────────────────────
hdr "Pre-flight checks"

if ! kubectl get nodes &>/dev/null; then
  err "kubectl cannot reach cluster. Are you on the control-plane?"
  exit 1
fi

NODES=$(kubectl get nodes --no-headers | awk '{print $1}' | tr '\n' ' ')
log "Cluster nodes detected: $NODES"

sudo mkdir -p /opt/course
sudo chown $USER:$USER /opt/course
# Create output directories on cp
mkdir -p /opt/course/{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17}
log "Created /opt/course/N directories for all questions"

# ── Q1 | Kubeconfig extraction ────────────────────────────────
hdr "Q1 | Kubeconfig"

cat > /opt/course/1/kubeconfig <<'EOF'
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: RkFLRS1DQS1DRVJULURBVEE=
    server: https://10.0.0.10:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: admin@internal
  name: cluster-admin
- context:
    cluster: kubernetes
    user: account-0027@internal
  name: cluster-w100
- context:
    cluster: kubernetes
    user: account-0028@internal
  name: cluster-w200
current-context: cluster-w200
kind: Config
preferences: {}
users:
- name: account-0027@internal
  user:
    client-certificate-data: RkFLRS1DTElFTlQtQ0VSVC1hY2NvdW50LTAwMjc=
    client-key-data: RkFLRS1DTElFTlQtS0VZLWFjY291bnQtMDAyNw==
- name: account-0028@internal
  user:
    client-certificate-data: RkFLRS1DTElFTlQtQ0VSVC1hY2NvdW50LTAwMjg=
    client-key-data: RkFLRS1DTElFTlQtS0VZLWFjY291bnQtMDAyOA==
- name: admin@internal
  user:
    client-certificate-data: RkFLRS1DTElFTlQtQ0VSVC1hZG1pbg==
    client-key-data: RkFLRS1DTElFTlQtS0VZLWFkbWlu
EOF
log "Q1: Kubeconfig placed at /opt/course/1/kubeconfig"

# ── Q2 | Storage - PV/PVC/Pod ────────────────────────────────
hdr "Q2 | Storage: PV / PVC / Pod"

kubectl create namespace project-t230 --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Namespace
metadata:
  name: project-t230
EOF
log "Q2: Namespace project-t230 ready"

# ── Q3 | StatefulSet scale ────────────────────────────────────
hdr "Q3 | StatefulSet scale"

kubectl create namespace project-h800 --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: o3db
  namespace: project-h800
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx"
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1-alpine
        resources:
          requests:
            cpu: 10m
            memory: 10Mi
EOF
log "Q3: StatefulSet o3db (2 replicas) in project-h800 created"

# ── Q4 | QoS / BestEffort pods ───────────────────────────────
hdr "Q4 | QoS - pods first to be terminated"

kubectl create namespace project-c13 --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

# Deployment WITH requests (should NOT be terminated first)
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: c13-2x3-api
  namespace: project-c13
spec:
  replicas: 2
  selector:
    matchLabels:
      app: c13-2x3-api
  template:
    metadata:
      labels:
        app: c13-2x3-api
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        resources:
          requests:
            cpu: 50m
            memory: 20Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: c13-runner-heavy
  namespace: project-c13
spec:
  replicas: 3
  selector:
    matchLabels:
      app: c13-runner-heavy
  template:
    metadata:
      labels:
        app: c13-runner-heavy
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        # NO resource requests - BestEffort QoS -> terminated first
EOF
log "Q4: Deployments in project-c13 created (c13-runner-heavy has no resource requests)"

# ── Q5 | RBAC ────────────────────────────────────────────────
hdr "Q5 | RBAC"

kubectl create namespace project-hamster --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
log "Q5: Namespace project-hamster ready"

# ── Q6 | DaemonSet ───────────────────────────────────────────
hdr "Q6 | DaemonSet"

kubectl create namespace project-tiger --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
log "Q6: Namespace project-tiger ready"

# ── Q7 | NetworkPolicy ───────────────────────────────────────
hdr "Q7 | NetworkPolicy"

kubectl create namespace project-snake --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: project-snake
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db1
  namespace: project-snake
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db1
  template:
    metadata:
      labels:
        app: db1
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db2
  namespace: project-snake
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db2
  template:
    metadata:
      labels:
        app: db2
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault
  namespace: project-snake
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
EOF
log "Q7: Deployments backend/db1/db2/vault in project-snake created"

# ── Q8 | Deployment with Pod anti-affinity ───────────────────
hdr "Q8 | Deployment / Pod Spread"
log "Q8: Uses project-tiger namespace (already created)"

# ── Q9 | ServiceAccount / RBAC / curl API ────────────────────
hdr "Q9 | ServiceAccount + API curl"

kubectl create namespace project-swan --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

kubectl -n project-swan create serviceaccount secret-reader \
  --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: project-swan
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader
  namespace: project-swan
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: project-swan
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# Create some secrets in the namespace for curl to find
kubectl -n project-swan create secret generic secret-alpha \
  --from-literal=key=alpha123 --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
kubectl -n project-swan create secret generic secret-beta \
  --from-literal=key=beta456 --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
log "Q9: ServiceAccount secret-reader + Role/RoleBinding + test secrets in project-swan"

# ── Q10 | CoreDNS update ─────────────────────────────────────
hdr "Q10 | CoreDNS"

mkdir -p /opt/course/16
log "Q10: /opt/course/16 directory ready for CoreDNS backup"

# ── Q11 | Node label/taint + Pod scheduling ──────────────────
hdr "Q11 | Node labels and scheduling"
# Label node01 for scheduling question
kubectl label node node01 disk=ssd --overwrite &>/dev/null || warn "Could not label node01 (may not exist yet)"
log "Q11: node01 labeled disk=ssd"

# ── Q12 | Cluster upgrade prep ───────────────────────────────
hdr "Q12 | Cluster info for upgrade question"
log "Q12: Run 'kubectl get nodes' during exam to see versions"

# ── Q13 | Troubleshoot broken pod ────────────────────────────
hdr "Q13 | Broken application (Troubleshooting)"

kubectl create namespace project-fault --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

# Deploy a pod with wrong image tag on purpose
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-broken
  namespace: project-fault
  labels:
    app: app-broken
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app-broken
  template:
    metadata:
      labels:
        app: app-broken
    spec:
      containers:
      - name: main
        image: nginx:DOES-NOT-EXIST
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app-broken-svc
  namespace: project-fault
spec:
  selector:
    app: app-broken-WRONG-LABEL
  ports:
  - port: 80
    targetPort: 80
EOF
log "Q13: Broken deployment in project-fault (wrong image + wrong service selector)"

# ── Q14 | etcd backup ────────────────────────────────────────
hdr "Q14 | etcd backup"
mkdir -p /opt/course/etcd-backup
log "Q14: /opt/course/etcd-backup directory ready"

# ── Q15 | Ingress / Gateway ──────────────────────────────────
hdr "Q15 | Ingress"

kubectl create namespace project-r500 --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: project-r500
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: project-r500
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
EOF
log "Q15: Deployment + Service web-app in project-r500"

# ── Q16 | Certificate check ──────────────────────────────────
hdr "Q16 | Certificate info"
mkdir -p /opt/course/14
log "Q16: /opt/course/14 directory ready"

# ── Q17 | Kustomize / HPA ────────────────────────────────────
hdr "Q17 | Kustomize / HPA"

kubectl create namespace api-gateway-staging --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
kubectl create namespace api-gateway-prod    --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

mkdir -p /opt/course/17/api-gateway/base
mkdir -p /opt/course/17/api-gateway/staging
mkdir -p /opt/course/17/api-gateway/prod

cat <<'EOF' > /opt/course/17/api-gateway/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
EOF

cat <<'EOF' > /opt/course/17/api-gateway/base/kustomization.yaml
resources:
- deployment.yaml
EOF

cat <<'EOF' > /opt/course/17/api-gateway/staging/kustomization.yaml
namespace: api-gateway-staging
resources:
- ../base
# TODO: Add HPA here (exam task)
EOF

cat <<'EOF' > /opt/course/17/api-gateway/prod/kustomization.yaml
namespace: api-gateway-prod
resources:
- ../base
# TODO: Add HPA here (exam task)
EOF

log "Q17: Kustomize overlay structure at /opt/course/17/api-gateway/"


# ── Summary ───────────────────────────────────────────────────
hdr "Setup Complete!"

echo ""
echo -e "${GREEN}✔ Environment ready for 17-question CKA Mock Exam${NC}"
echo ""
echo "  Namespaces created:"
kubectl get ns | grep -E 'project-|api-gateway|cert-' | awk '{print "    - "$1}' 2>/dev/null || true
echo ""
echo "  Nodes:"
kubectl get nodes --no-headers | awk '{print "    - "$1" ("$2")"}'
echo ""
echo -e "${YELLOW}  Remember to run: source ~/.bashrc${NC}"
echo ""
echo "  Good luck! 🎯"
