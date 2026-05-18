#!/bin/bash
# ============================================================
# CKA Mock Exam 2 - Environment Setup Script
# Based on killer.sh CKA Simulator B (Kubernetes 1.35)
# Target: Vagrant cluster (cp, node01, node02)
# Run from control-plane: ssh cp && ./setup-cka-mock-exam-2.sh
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

if [[ -z "$KUBECONFIG" ]]; then
  INVOKING_USER="${SUDO_USER:-$USER}"
  CANDIDATE_KC="/home/${INVOKING_USER}/.kube/config"
  if [[ -f "$CANDIDATE_KC" ]]; then
    export KUBECONFIG="$CANDIDATE_KC"
    log "KUBECONFIG not set — using ${KUBECONFIG}"
  elif [[ -f "/root/.kube/config" ]]; then
    export KUBECONFIG="/root/.kube/config"
    log "Using /root/.kube/config"
  fi
fi

if ! kubectl get nodes &>/dev/null; then
  err "kubectl cannot reach cluster. Tried KUBECONFIG=${KUBECONFIG:-<not set>}"
  err "Fix: export KUBECONFIG=/path/to/kubeconfig and re-run, or run without sudo"
  exit 1
fi

NODES=$(kubectl get nodes --no-headers | awk '{print $1}' | tr '\n' ' ')
log "Cluster nodes: $NODES"

sudo mkdir -p /opt/course
sudo chown $USER:$USER /opt/course
# Create output directories
for i in 3 5 7 8 10 11 12 13 1 2 14 15 16 17; do
  mkdir -p /opt/course/$i
done
log "Created /opt/course/N directories"

# ── Q1 | DNS / Headless Service ───────────────────────────────
hdr "Q1 | DNS / FQDN / Headless Service"

kubectl create namespace lima-control   --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
kubectl create namespace lima-workload  --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

# Headless service + pods in lima-workload
cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Service
metadata:
  name: department
  namespace: lima-workload
spec:
  clusterIP: None
  selector:
    name: department
  ports:
  - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: section
  namespace: lima-workload
spec:
  selector:
    name: section
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: section100
  namespace: lima-workload
  labels:
    name: section
spec:
  hostname: section100
  subdomain: section
  containers:
  - name: main
    image: nginx:1-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: section200
  namespace: lima-workload
  labels:
    name: section
spec:
  hostname: section200
  subdomain: section
  containers:
  - name: main
    image: nginx:1-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: dept-pod-1
  namespace: lima-workload
  labels:
    name: department
spec:
  containers:
  - name: main
    image: nginx:1-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: dept-pod-2
  namespace: lima-workload
  labels:
    name: department
spec:
  containers:
  - name: main
    image: nginx:1-alpine
EOF

# Controller deployment with ConfigMap containing wrong DNS values
cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: control-config
  namespace: lima-control
data:
  DNS_1: "PLACEHOLDER"
  DNS_2: "PLACEHOLDER"
  DNS_3: "PLACEHOLDER"
  DNS_4: "PLACEHOLDER"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controller
  namespace: lima-control
spec:
  replicas: 2
  selector:
    matchLabels:
      app: controller
  template:
    metadata:
      labels:
        app: controller
    spec:
      containers:
      - name: main
        image: nginx:1-alpine
        command: ["/bin/sh", "-c"]
        args:
        - |
          set -x
          while true; do
            nslookup $DNS_1 || true
            nslookup $DNS_2 || true
            nslookup $DNS_3 || true
            nslookup $DNS_4 || true
            sleep 30
          done
        envFrom:
        - configMapRef:
            name: control-config
EOF
log "Q1: lima-control + lima-workload namespaces, headless service, section pods, controller deployment ready"

# ── Q2 | Static Pod + NodePort Service ───────────────────────
hdr "Q2 | Static Pod + NodePort Service"
log "Q2: No pre-setup needed — you will create the static pod manifest manually during the exam"
log "Q2: Static pod manifests directory: /etc/kubernetes/manifests/"

# ── Q3 | Kubelet cert info ────────────────────────────────────
hdr "Q3 | Kubelet Certificate Info"
mkdir -p /opt/course/3
log "Q3: /opt/course/3/ ready for certificate-info.txt"
log "Q3: On node01 check: /var/lib/kubelet/pki/kubelet-client-current.pem and kubelet.crt"

# ── Q4 | ReadinessProbe + cross-pod ──────────────────────────
hdr "Q4 | ReadinessProbe with cross-pod check"

cat <<'EOF' | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Service
metadata:
  name: service-am-i-ready
  namespace: default
  labels:
    id: cross-server-ready
spec:
  selector:
    id: cross-server-ready
  ports:
  - port: 80
    targetPort: 80
EOF
log "Q4: Service service-am-i-ready created in default namespace"

# ── Q5 | kubectl sorting scripts ─────────────────────────────
hdr "Q5 | kubectl sorting"
mkdir -p /opt/course/5
touch /opt/course/5/find_pods.sh
touch /opt/course/5/find_pods_uid.sh
chmod +x /opt/course/5/find_pods.sh /opt/course/5/find_pods_uid.sh
log "Q5: /opt/course/5/find_pods.sh and find_pods_uid.sh created (empty, you fill them)"

# ── Q6 | Broken kubelet ───────────────────────────────────────
hdr "Q6 | Fix Kubelet (simulated)"
warn "Q6: The kubelet breakage on node01 must be done manually."
warn "Q6: To simulate: ssh node01, sudo -i"
warn "Q6: Edit /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf to set ExecStart=/usr/local/bin/kubelet"
warn "Q6: Then: systemctl daemon-reload && systemctl restart kubelet"

# ── Q7 | etcd operations ─────────────────────────────────────
hdr "Q7 | etcd Operations"
mkdir -p /opt/course/7
log "Q7: /opt/course/7/ ready for etcd-version and etcd-snapshot.db"

# ── Q8 | Controlplane info ────────────────────────────────────
hdr "Q8 | Controlplane Components Info"
mkdir -p /opt/course/8
log "Q8: /opt/course/8/ ready for controlplane-components.txt"

# ── Q9 | Kill scheduler / manual scheduling ───────────────────
hdr "Q9 | Manual Pod Scheduling"
log "Q9: No pre-setup needed — you will stop the scheduler and schedule manually during exam"

# ── Q10 | Dynamic PV + Job ────────────────────────────────────
hdr "Q10 | PV Dynamic Provisioning + Job"

kubectl create namespace project-bern --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
mkdir -p /opt/course/10

cat <<'EOF' > /opt/course/10/backup.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: backup
  namespace: project-bern
spec:
  backoffLimit: 0
  template:
    spec:
      volumes:
      - name: backup
        emptyDir: {}
      containers:
      - name: bash
        image: bash:5
        command:
        - bash
        - -c
        - |
          set -x
          touch /backup/backup-$(date +%Y-%m-%d-%H-%M-%S).tar.gz
          sleep 15
        volumeMounts:
        - name: backup
          mountPath: /backup
      restartPolicy: Never
EOF
log "Q10: /opt/course/10/backup.yaml placed, namespace project-bern ready"

# ── Q11 | Secret + Pod ───────────────────────────────────────
hdr "Q11 | Secrets + Pod"

kubectl create namespace secret --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
mkdir -p /opt/course/11

cat <<'EOF' > /opt/course/11/secret1.yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret1
data:
  halt: IyEvYmluL3NoCiMjIyBCRUdJTiBJTklUIElORk8KIyBQcm92aWRlczogaGFsdAo=
EOF
log "Q11: /opt/course/11/secret1.yaml placed, namespace secret ready"

# ── Q12 | Pod on controlplane node ───────────────────────────
hdr "Q12 | Schedule Pod on Controlplane"
log "Q12: No pre-setup needed — you will create the pod with tolerations during the exam"

# ── Q13 | Multi-container Pod ────────────────────────────────
hdr "Q13 | Multi-container Pod"
log "Q13: No pre-setup needed — you will create the multi-container pod during the exam"

# ── Q14 | Cluster information ────────────────────────────────
hdr "Q14 | Cluster Information"
mkdir -p /opt/course/14
cat <<'EOF' > /opt/course/14/cluster-info
# Fill in the answers during the exam
1: [ANSWER]
2: [ANSWER]
3: [ANSWER]
4: [ANSWER]
5: [ANSWER]
EOF
log "Q14: /opt/course/14/cluster-info template ready"

# ── Q15 | Cluster event logging ──────────────────────────────
hdr "Q15 | Cluster Event Logging"
mkdir -p /opt/course/15
touch /opt/course/15/cluster_events.sh
touch /opt/course/15/pod_kill.log
touch /opt/course/15/container_kill.log
chmod +x /opt/course/15/cluster_events.sh
log "Q15: /opt/course/15/ files created"

# ── Q16 | Namespaced resources + Roles ───────────────────────
hdr "Q16 | Namespaced Resources + Roles"
mkdir -p /opt/course/16

# Create project namespaces with varying number of roles
for ns in project-alpha project-beta project-gamma project-delta project-epsilon; do
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
done

# project-beta gets the most roles (the "crowded" one to find)
for i in $(seq 1 15); do
  cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-$i
  namespace: project-beta
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
EOF
done

# Others get fewer
for i in 1 2 3; do
  cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-$i
  namespace: project-alpha
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
EOF
done

for i in 1 2 3 4 5 6 7; do
  cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-$i
  namespace: project-gamma
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
EOF
done

log "Q16: project-alpha(3), project-beta(15), project-gamma(7), project-delta(0), project-epsilon(0) roles created"

# ── Q17 | Kustomize + CRD operator ───────────────────────────
hdr "Q17 | Kustomize + CRDs + RBAC"

mkdir -p /opt/course/17/operator/base
mkdir -p /opt/course/17/operator/prod

# CRD: students
cat <<'EOF' > /opt/course/17/operator/base/crds.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: students.education.local
spec:
  group: education.local
  names:
    kind: Student
    listKind: StudentList
    plural: students
    singular: student
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              name:
                type: string
              description:
                type: string
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: classes.education.local
spec:
  group: education.local
  names:
    kind: Class
    listKind: ClassList
    plural: classes
    singular: class
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              name:
                type: string
              level:
                type: string
EOF

cat <<'EOF' > /opt/course/17/operator/base/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: operator
  namespace: NAMESPACE_REPLACE
EOF

# RBAC - intentionally MISSING students and classes (the bug to fix)
cat <<'EOF' > /opt/course/17/operator/base/rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: operator-role
  namespace: NAMESPACE_REPLACE
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operator-rolebinding
  namespace: NAMESPACE_REPLACE
subjects:
- kind: ServiceAccount
  name: operator
  namespace: NAMESPACE_REPLACE
roleRef:
  kind: Role
  name: operator-role
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<'EOF' > /opt/course/17/operator/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: operator
  namespace: NAMESPACE_REPLACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: operator
  template:
    metadata:
      labels:
        app: operator
    spec:
      serviceAccountName: operator
      containers:
      - name: operator
        image: bitnami/kubectl:latest
        command: ["/bin/sh", "-c"]
        args:
        - |
          set -x
          while true; do
            kubectl get students
            kubectl get classes
            sleep 10
          done
EOF

cat <<'EOF' > /opt/course/17/operator/base/students.yaml
apiVersion: education.local/v1
kind: Student
metadata:
  name: student1
spec:
  name: Alice Johnson
  description: Expert in Kubernetes networking
---
apiVersion: education.local/v1
kind: Student
metadata:
  name: student2
spec:
  name: Bob Smith
  description: Specialist in cluster security
---
apiVersion: education.local/v1
kind: Student
metadata:
  name: student3
spec:
  name: Carol Williams
  description: Expert in container orchestration
EOF

cat <<'EOF' > /opt/course/17/operator/base/classes.yaml
apiVersion: education.local/v1
kind: Class
metadata:
  name: advanced
spec:
  name: Advanced Kubernetes
  level: expert
EOF

cat <<'EOF' > /opt/course/17/operator/base/kustomization.yaml
resources:
- crds.yaml
- serviceaccount.yaml
- rbac.yaml
- deployment.yaml
- students.yaml
- classes.yaml
EOF

# Prod overlay
cat <<'EOF' > /opt/course/17/operator/prod/kustomization.yaml
namespace: operator-prod
resources:
- ../base
patches:
- patch: |-
    - op: replace
      path: /metadata/namespace
      value: operator-prod
  target:
    kind: Role
- patch: |-
    - op: replace
      path: /metadata/namespace
      value: operator-prod
  target:
    kind: RoleBinding
- patch: |-
    - op: replace
      path: /metadata/namespace
      value: operator-prod
  target:
    kind: ServiceAccount
- patch: |-
    - op: replace
      path: /metadata/namespace
      value: operator-prod
  target:
    kind: Deployment
EOF

# Apply CRDs first, then the rest
kubectl apply -f /opt/course/17/operator/base/crds.yaml &>/dev/null || warn "CRDs may already exist"

kubectl create namespace operator-prod --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
kubectl kustomize /opt/course/17/operator/prod | kubectl apply -f - &>/dev/null || warn "Q17 operator-prod deploy had warnings (ok if CRDs just created)"
log "Q17: Kustomize operator structure at /opt/course/17/operator/"

# ── Aliases ───────────────────────────────────────────────────
hdr "Shell aliases"

grep -q "CKA Mock Exam 2" ~/.bashrc || cat >> ~/.bashrc <<'ALIASES'

# CKA Mock Exam 2 aliases
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period 0"
source <(kubectl completion bash)
complete -F __start_kubectl k
ALIASES

log "Aliases added to ~/.bashrc — run: source ~/.bashrc"

# ── Summary ───────────────────────────────────────────────────
hdr "Setup Complete!"

echo ""
echo -e "${GREEN}✔ Environment ready for CKA Mock Exam 2 (17 questions)${NC}"
echo ""
echo "  Namespaces created:"
kubectl get ns --no-headers | grep -E 'lima-|project-|secret|operator-|project-bern' \
  | awk '{print "    - "$1}' 2>/dev/null || true
echo ""
echo "  Nodes:"
kubectl get nodes --no-headers | awk '{print "    - "$1" ("$2")"}'
echo ""
echo -e "${YELLOW}  Run: source ~/.bashrc${NC}"
echo ""
echo -e "${YELLOW}  Manual step for Q6:${NC}"
echo "    ssh node01 && sudo -i"
echo "    Edit /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf"
echo "    Change ExecStart path to /usr/local/bin/kubelet"
echo "    systemctl daemon-reload && systemctl restart kubelet"
echo ""
echo "  Good luck! 🎯"
