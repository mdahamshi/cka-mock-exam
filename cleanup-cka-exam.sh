#!/bin/bash
# ============================================================
# CKA Exam - General Cleanup Script
# Handles: stuck Terminating namespaces, orphaned CNI sandboxes,
# force-deleted pods, Calico reinstall, finalizer removal.
# Run from control-plane: ssh cp && ./cleanup-cka-exam.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[CLEAN]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
hdr()  { echo -e "\n${CYAN}================================================${NC}"; \
         echo -e "${CYAN}  $1${NC}"; \
         echo -e "${CYAN}================================================${NC}"; }

# ---- Pre-flight -----------------------------------------------
hdr "Pre-flight"

if [[ -z "$KUBECONFIG" ]]; then
  INVOKING_USER="${SUDO_USER:-$USER}"
  for candidate in \
      "/home/${INVOKING_USER}/.kube/config" \
      "/root/.kube/config" \
      "/etc/kubernetes/admin.conf"; do
    if [[ -f "$candidate" ]]; then
      export KUBECONFIG="$candidate"
      log "Using KUBECONFIG=$KUBECONFIG"
      break
    fi
  done
fi

if ! kubectl get nodes &>/dev/null; then
  err "kubectl cannot reach cluster. Tried KUBECONFIG=${KUBECONFIG:-<not set>}"
  err "Fix: export KUBECONFIG=/etc/kubernetes/admin.conf"
  exit 1
fi

log "Cluster reachable. Nodes:"
kubectl get nodes --no-headers | awk '{print "  "$1" ("$2")"}'

# Namespaces that belong to a default Kubernetes install - never deleted
DEFAULT_NAMESPACES="default kube-system kube-public kube-node-lease"

# CNI namespaces - deleted last, after all workload namespaces are gone
CNI_NAMESPACES="calico-system calico-apiserver tigera-operator"

# ---- Step 1: Force-delete all stuck Terminating pods ---------
hdr "Step 1: Force-delete stuck Terminating pods"

for ns in $(kubectl get ns --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null); do
  STUCK=$(kubectl -n "$ns" get pods --no-headers 2>/dev/null \
    | awk '$3=="Terminating" {print $1}')
  if [[ -n "$STUCK" ]]; then
    echo "$STUCK" | xargs kubectl -n "$ns" delete pod \
      --force --grace-period=0 --ignore-not-found 2>/dev/null || true
    log "Force-deleted stuck pods in $ns"
  fi
done

sleep 5

# ---- Step 2: Delete namespaces (workload first, CNI last) ----
hdr "Step 2: Delete non-default namespaces"

WORKLOAD_NS=()
CNI_NS_TO_DELETE=()

for ns in $(kubectl get ns --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null); do
  if echo "$DEFAULT_NAMESPACES" | grep -qw "$ns"; then
    log "Keeping: $ns"
    continue
  fi
  if echo "$CNI_NAMESPACES" | grep -qw "$ns"; then
    CNI_NS_TO_DELETE+=("$ns")
  else
    WORKLOAD_NS+=("$ns")
  fi
done

delete_ns_with_fallback() {
  local ns="$1"
  log "Deleting namespace: $ns ..."

  kubectl delete namespace "$ns" --ignore-not-found \
    --wait=true --timeout=60s 2>/dev/null && \
    log "Namespace $ns deleted cleanly" && return

  # Still exists - remove finalizers
  if kubectl get namespace "$ns" &>/dev/null; then
    warn "Namespace $ns stuck - removing finalizers"
    kubectl get namespace "$ns" -o json \
      | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['spec']['finalizers'] = []
print(json.dumps(d))
" | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - &>/dev/null
    sleep 3
    kubectl get namespace "$ns" &>/dev/null \
      && warn "Namespace $ns still exists - may need manual intervention" \
      || log "Namespace $ns removed via finalizer patch"
  fi
}

for ns in "${WORKLOAD_NS[@]}"; do
  delete_ns_with_fallback "$ns"
done

if [[ ${#CNI_NS_TO_DELETE[@]} -gt 0 ]]; then
  log "Waiting 10s before removing CNI namespaces..."
  sleep 10
  for ns in "${CNI_NS_TO_DELETE[@]}"; do
    delete_ns_with_fallback "$ns"
  done
fi

# ---- Step 3: Clean default namespace -------------------------
hdr "Step 3: Clean default namespace"

kubectl -n default delete pods --all --force --grace-period=0 \
  --ignore-not-found 2>/dev/null || true

for resource in deployments statefulsets daemonsets replicasets jobs cronjobs \
                ingresses networkpolicies persistentvolumeclaims \
                horizontalpodautoscalers roles rolebindings configmaps; do
  kubectl -n default delete "$resource" --all --ignore-not-found 2>/dev/null || true
  log "Cleaned $resource in default"
done

kubectl -n default get svc --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | grep -v '^kubernetes$' \
  | xargs -r kubectl -n default delete svc --ignore-not-found 2>/dev/null || true

kubectl -n default get sa --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | grep -v '^default$' \
  | xargs -r kubectl -n default delete sa --ignore-not-found 2>/dev/null || true

kubectl -n default get secret --no-headers \
  -o custom-columns=NAME:.metadata.name,TYPE:.type 2>/dev/null \
  | grep -v 'kubernetes.io/service-account-token' \
  | awk '{print $1}' \
  | xargs -r kubectl -n default delete secret --ignore-not-found 2>/dev/null || true

log "Default namespace cleaned"

# ---- Step 4: Cluster-scoped resources ------------------------
hdr "Step 4: Cluster-scoped resources"

kubectl get pv --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | xargs -r kubectl delete pv --force --grace-period=0 --ignore-not-found 2>/dev/null || true
log "Deleted PersistentVolumes"

kubectl get sc --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | grep -v -E '^(standard|local-path)$' \
  | xargs -r kubectl delete sc --ignore-not-found 2>/dev/null || true
log "Deleted non-default StorageClasses"

# CRDs: skip Calico/Tigera (managed by CNI reinstall)
kubectl get crd --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | grep -v -E '\.(projectcalico\.org|tigera\.io)$' \
  | xargs -r kubectl delete crd --ignore-not-found 2>/dev/null || true
log "Deleted non-CNI CRDs"

# ClusterRoles: skip system, kubeadm, calico, tigera and well-known defaults
kubectl get clusterrole --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | grep -v -E '^(system:|kubeadm:|cluster-admin$|admin$|edit$|view$|calico|tigera)' \
  | xargs -r kubectl delete clusterrole --ignore-not-found 2>/dev/null || true
log "Deleted non-system ClusterRoles"

kubectl get clusterrolebinding --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | grep -v -E '^(system:|kubeadm:|cluster-admin$|calico|tigera)' \
  | xargs -r kubectl delete clusterrolebinding --ignore-not-found 2>/dev/null || true
log "Deleted non-system ClusterRoleBindings"

kubectl get ingressclass --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | xargs -r kubectl delete ingressclass --ignore-not-found 2>/dev/null || true
log "Deleted IngressClasses"

# ---- Step 5: Node cleanup ------------------------------------
hdr "Step 5: Node labels, taints, cordons"

for node in $(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name); do
  if kubectl get node "$node" -o jsonpath='{.spec.unschedulable}' 2>/dev/null | grep -q true; then
    kubectl uncordon "$node"
    log "Uncordoned $node"
  fi

  CUSTOM_LABELS=$(kubectl get node "$node" -o json 2>/dev/null \
    | python3 -c "
import json, sys
labels = json.load(sys.stdin)['metadata']['labels']
skip = ('kubernetes.io/', 'beta.kubernetes.io/', 'node-role.kubernetes.io/', 'node.kubernetes.io/')
custom = [k for k in labels if not any(k.startswith(p) for p in skip)]
print(' '.join(k + '-' for k in custom))
" 2>/dev/null)
  if [[ -n "$CUSTOM_LABELS" ]]; then
    kubectl label node "$node" $CUSTOM_LABELS 2>/dev/null || true
    log "Removed custom labels from $node: $CUSTOM_LABELS"
  fi

  CUSTOM_TAINTS=$(kubectl get node "$node" -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
taints = data.get('spec', {}).get('taints', [])
custom = []
for t in taints:
    k = t['key']
    if k.startswith('node.kubernetes.io/') or k == 'node-role.kubernetes.io/control-plane':
        continue
    custom.append(k + '=' + t.get('value', '') + ':' + t['effect'])
print('\n'.join(custom))
" 2>/dev/null)
  if [[ -n "$CUSTOM_TAINTS" ]]; then
    while IFS= read -r taint; do
      [[ -z "$taint" ]] && continue
      KEY=$(echo "$taint" | cut -d= -f1)
      REST=$(echo "$taint" | cut -d= -f2-)
      VAL=$(echo "$REST"  | cut -d: -f1)
      EFF=$(echo "$REST"  | cut -d: -f2)
      if [[ -n "$VAL" ]]; then
        kubectl taint node "$node" "${KEY}=${VAL}:${EFF}-" 2>/dev/null || true
      else
        kubectl taint node "$node" "${KEY}:${EFF}-" 2>/dev/null || true
      fi
      log "Removed taint '$taint' from $node"
    done <<< "$CUSTOM_TAINTS"
  fi
done

# ---- Step 6: Static pod manifests ----------------------------
hdr "Step 6: Static pod manifests"

DEFAULT_MANIFESTS="etcd.yaml kube-apiserver.yaml kube-controller-manager.yaml kube-scheduler.yaml"
MANIFESTS_DIR="/etc/kubernetes/manifests"

for f in "$MANIFESTS_DIR"/*.yaml; do
  [[ -f "$f" ]] || continue
  fname=$(basename "$f")
  if ! echo "$DEFAULT_MANIFESTS" | grep -qw "$fname"; then
    sudo rm -f "$f"
    log "Removed exam static pod manifest: $fname"
  fi
done

# Restore kube-scheduler if moved (Q9 scenario)
SCHED="$MANIFESTS_DIR/kube-scheduler.yaml"
SCHED_BCK="/etc/kubernetes/kube-scheduler.yaml"
if [[ ! -f "$SCHED" && -f "$SCHED_BCK" ]]; then
  sudo mv "$SCHED_BCK" "$SCHED"
  log "Restored kube-scheduler manifest"
fi

# ---- Step 7: Check kubelet on worker nodes -------------------
hdr "Step 7: Kubelet on worker nodes"

for worker in node01 node02; do
  if ssh -o ConnectTimeout=5 -o BatchMode=yes "$worker" true 2>/dev/null; then
    STATUS=$(ssh "$worker" "systemctl is-active kubelet" 2>/dev/null)
    if [[ "$STATUS" != "active" ]]; then
      warn "kubelet on $worker is '$STATUS' - attempting fix"
      ssh "$worker" "sudo sed -i \
        's|ExecStart=/usr/local/bin/kubelet|ExecStart=/usr/bin/kubelet|g' \
        /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf && \
        sudo systemctl daemon-reload && sudo systemctl restart kubelet" 2>/dev/null \
        && log "kubelet on $worker restarted" \
        || warn "Could not auto-fix kubelet on $worker - fix manually"
    else
      log "kubelet on $worker: active"
    fi
  else
    warn "Cannot SSH to $worker - skipping kubelet check"
  fi
done

# ---- Step 8: Reinstall Calico if missing ---------------------
hdr "Step 8: Calico CNI"

CALICO_NODES=$(kubectl -n kube-system get pods -l k8s-app=calico-node \
  --no-headers 2>/dev/null | wc -l)

if [[ "$CALICO_NODES" -eq 0 ]]; then
  warn "Calico not found - reinstalling"
  CALICO_VERSION="v3.29.0"
  log "Applying Calico $CALICO_VERSION ..."
  kubectl apply -f \
    "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" \
    2>/dev/null \
    && log "Calico manifest applied" \
    || err "Failed to apply Calico - check internet access on cp"

  log "Waiting up to 120s for calico-node pods..."
  kubectl -n kube-system wait --for=condition=Ready pod \
    -l k8s-app=calico-node --timeout=120s 2>/dev/null \
    && log "Calico Ready" \
    || warn "Calico not Ready yet - check: kubectl -n kube-system get pods | grep calico"
else
  NOT_RUNNING=$(kubectl -n kube-system get pods -l k8s-app=calico-node \
    --no-headers 2>/dev/null | grep -v Running | wc -l)
  if [[ "$NOT_RUNNING" -gt 0 ]]; then
    warn "$NOT_RUNNING Calico pod(s) not Running - restarting"
    kubectl -n kube-system rollout restart daemonset calico-node 2>/dev/null || true
    kubectl -n kube-system rollout restart deployment calico-kube-controllers 2>/dev/null || true
  else
    log "Calico: all $CALICO_NODES node pods Running"
  fi
fi

# ---- Step 9: /opt/course cleanup -----------------------------
hdr "Step 9: /opt/course"

if [[ -d /opt/course ]]; then
  sudo rm -rf /opt/course
  log "Deleted /opt/course"
else
  log "/opt/course not found - already clean"
fi

# ---- Step 10: Final verification -----------------------------
hdr "Step 10: Final verification"

log "Waiting 15s for everything to settle..."
sleep 15

echo ""
echo "Nodes:"
kubectl get nodes 2>/dev/null || err "Cannot reach API server"
echo ""

echo "Remaining namespaces:"
kubectl get ns --no-headers 2>/dev/null | awk '{print "  "$1" ["$2"]"}'
echo ""

echo "Non-Running/Completed pods:"
STUCK_PODS=$(kubectl get pods -A --no-headers 2>/dev/null \
  | grep -v -E '(Running|Completed)' || true)
if [[ -z "$STUCK_PODS" ]]; then
  echo "  None - all clean"
else
  echo "$STUCK_PODS" | awk '{print "  "$0}'
fi
echo ""

echo "PVs:"
PVS=$(kubectl get pv --no-headers 2>/dev/null || true)
[[ -z "$PVS" ]] && echo "  None" || echo "$PVS" | awk '{print "  "$0}'
echo ""

echo "CRDs:"
CRDS=$(kubectl get crd --no-headers 2>/dev/null || true)
[[ -z "$CRDS" ]] && echo "  None" || echo "$CRDS" | awk '{print "  "$0}'
echo ""

echo -e "${GREEN}Done!${NC}"
