# CKA Mock Exam Kit

A self-hosted CKA practice exam modeled after the [killer.sh](https://killer.sh) simulator.
17 hands-on questions covering all five CKA domains, designed to run on your own Vagrant-based
Kubernetes cluster.

---

## Prerequisites

This kit assumes you already have a working Kubernetes cluster. Specifically:

- **Kubernetes is installed and running** on all nodes (kubeadm-bootstrapped)
- **Three nodes** accessible via SSH:
  - `ssh cp` — control-plane node
  - `ssh node01` — worker node
  - `ssh node02` — worker node
- `kubectl` is configured on `cp` and can reach the cluster (`kubectl get nodes` works)
- `etcdctl` is available on `cp` (needed for the etcd backup question)
- `kubeadm` is available on `cp` and worker nodes
- Internet access from nodes (to pull images like `nginx:1-alpine`, `httpd:2-alpine`)
- You are running as a user with `sudo` access (or root)

> If you are using the Vagrant setup from KodeKloud or a similar CKA lab environment,
> this kit works out of the box. I also provided Vagrantfile in this repo for virsh instead virtualbox

---

## Files

| File | Description |
|------|-------------|
| `setup-cka-mock-exam.sh` | Environment setup script — run once before starting the exam |
| `cka-mock-exam.md` | The 17 exam questions + collapsed answer key |
| `setup-cka-mock-exam-2.sh` | Environment setup script — run once before starting exam 2 |
| `cka-mock-exam-2.md` | The 17 exam 2 questions + collapsed answer key |
| `setup-cka-mock-exam-3.sh` | Environment setup script — run once before starting exam 3 |
| `cka-mock-exam-3.md` | The 17 exam 3 questions + collapsed answer key |
| `Vagrantfile` | Vagrantfile for virsh , see [kodekloud guide](https://github.com/kodekloudhub/certified-kubernetes-administrator-course/blob/master/kubeadm-clusters/virtualbox/docs/01-prerequisites.md) for more info|
| `README.md` | This file |
| `cleanup-cka-exam.sh` | A clean up script, run with cation, it dletes all resource except kubernetes defaults|

---

## Setup

Run the setup script **from the control-plane node** (`cp`):

```bash
# Copy the script to cp
scp setup-cka-mock-exam.sh cp:~/

# SSH into the control-plane
ssh cp
# Prepare exam folder
sudo mkdir -p /opt/course
sudo chown $USER:$USER /opt/course

# Make executable and run
chmod +x setup-cka-mock-exam.sh
./setup-cka-mock-exam.sh

# Load the aliases into your current shell
source ~/.bashrc
```

The script will:

- Create all required namespaces (`project-t230`, `project-h800`, `project-c13`, etc.)
- Deploy pre-configured workloads needed by specific questions (StatefulSet, broken Deployment, etc.)
- Set up RBAC resources for the ServiceAccount questions
- Place kubeconfig and Kustomize files under `/opt/course/`
- Add exam-standard shell aliases: `k=kubectl`, `$do`, `$now`, kubectl tab-completion

---

## Taking the Exam

1. Open `cka-mock-exam.md` as your question sheet
2. Set a **120-minute timer**
3. Work through questions in any order — harder questions can be skipped and revisited
4. The answer key is at the bottom of the file inside a collapsed `<details>` block —
   try not to peek until you're done

```bash
# Useful aliases loaded by the setup script
alias k=kubectl
export do="--dry-run=client -o yaml"   # e.g.: k run pod1 --image=nginx $do
export now="--force --grace-period 0"  # e.g.: k delete pod pod1 $now
```

---

## Question Topics & Domain Coverage

### Exam 1

| # | Topic | CKA Domain | Weight |
|---|-------|-----------|--------|
| 1 | Kubeconfig context extraction | Cluster Architecture | 4% |
| 2 | PersistentVolume / PVC / Pod | Storage | 7% |
| 3 | Scale StatefulSet | Workloads | 3% |
| 4 | QoS — identify BestEffort pods | Troubleshooting | 5% |
| 5 | RBAC — ServiceAccount / Role / RoleBinding | Cluster Architecture | 6% |
| 6 | DaemonSet on all nodes (incl. control-plane) | Workloads | 5% |
| 7 | NetworkPolicy — egress rules | Networking | 7% |
| 8 | Deployment with topology spread constraints | Workloads | 6% |
| 9 | Contact K8s API from inside a Pod via curl | Cluster Architecture | 5% |
| 10 | CoreDNS configuration update | Networking | 4% |
| 11 | Node selector, taint & toleration | Scheduling | 4% |
| 12 | Cluster upgrade — worker node (kubeadm) | Cluster Architecture | 8% |
| 13 | Troubleshoot broken Deployment + Service | Troubleshooting | 8% |
| 14 | etcd snapshot backup | Cluster Architecture | 8% |
| 15 | Ingress creation | Networking | 5% |
| 16 | Certificate expiration check | Cluster Architecture | 4% |
| 17 | Kustomize overlays + HorizontalPodAutoscaler | Workloads | 7% |

**Passing score: 66%**

---

### Exam 2

**New topics covered (directly from the killer.sh B simulator):**

| # | Topic | What makes it different |
|---|-------|------------------------|
| 1 | DNS FQDNs | Headless service, pod hostname/subdomain, pod-IP DNS format |
| 2 | Static Pod + NodePort | Manual manifest placement in manifests dir |
| 3 | Kubelet cert inspection | Client vs server cert, openssl, Extended Key Usage |
| 4 | Cross-pod ReadinessProbe | wget-based readiness, Service-dependent readiness |
| 5 | kubectl sort scripts | `--sort-by` flags, bash scripts |
| 6 | Fix broken kubelet | Wrong binary path in systemd drop-in |
| 7 | etcd version + snapshot | exec into etcd pod for version, etcdctl snapshot |
| 8 | Controlplane component types | process vs static-pod vs pod, coredns as deployment |
| 9 | Kill scheduler + manual schedule | `nodeName` field, replace --force |
| 10 | Dynamic PV + StorageClass | `rancher.io/local-path`, `Retain` policy, Job PVC |
| 17 | Kustomize + CRD + RBAC fix | Log-driven debugging, fix Role, add CR |

---

### Exam 3 (Kubernetes 1.35 | Post-Feb 2025 Curriculum)

| # | Topic | CKA Domain | Weight |
|---|-------|-----------|--------|
| 1 | Helm template + install with values | Cluster Architecture | 6% |
| 2 | Gateway API — HTTPRoute + TLS, migrate from Ingress | Networking | 8% |
| 3 | PriorityClass creation + deployment patch | Workloads | 5% |
| 4 | Sidecar container + shared emptyDir volume | Workloads | 6% |
| 5 | ConfigMap edit — nginx TLS protocol update | Workloads | 4% |
| 6 | Troubleshoot kube-apiserver (wrong etcd endpoint) | Troubleshooting | 8% |
| 7 | NetworkPolicy — multi-tier ingress rules | Networking | 6% |
| 8 | StorageClass + static PV bind + dynamic provisioning | Storage | 6% |
| 9 | PodDisruptionBudget | Workloads | 4% |
| 10 | CronJob + manual Job trigger | Workloads | 5% |
| 11 | Troubleshoot broken Service (selector + port) | Troubleshooting | 5% |
| 12 | RBAC ClusterRole aggregation | Cluster Architecture | 5% |
| 13 | Deployment rollout history + rollback | Workloads | 5% |
| 14 | Init container + readinessProbe | Workloads | 5% |
| 15 | Node drain with PDB constraint | Cluster Architecture | 5% |
| 16 | ResourceQuota + LimitRange + default injection | Workloads | 5% |
| 17 | Helm template save + Kustomize image patch | Cluster Architecture | 7% |

**Passing score: 66%**

> **Note for Q6:** Break the apiserver **before** starting your timer:
> ```bash
> sudo sed -i 's|--etcd-servers=https://127.0.0.1:2379|--etcd-servers=https://127.0.0.1:1234/|' \
>   /etc/kubernetes/manifests/kube-apiserver.yaml
> ```

---

## Notes

- **Question 12 (cluster upgrade, Exam 1)** requires a real version mismatch on `node01` to be fully
  realistic. If your nodes all run the same version, you can still practice the drain/uncordon
  workflow and the `kubeadm upgrade node` command flow.
- **Question 15 (Ingress, Exam 1)** requires an IngressClass and Ingress controller to be installed
  (e.g. ingress-nginx). If none is present, the Ingress resource can still be created and
  inspected — the address field will just remain empty.
- **Question 2 (Gateway API, Exam 3)** requires Gateway API CRDs. The setup script installs them,
  or they can be applied manually from the question instructions.
- All questions are designed to work with **Kubernetes v1.29+**. Exam 3 is based on **v1.35**.

---

## Real Exam Tips

- In the real CKA exam you are allowed to open one extra browser tab pointing to:
  `kubernetes.io/docs`, `kubernetes.io/blog`, Helm docs, and Gateway API docs.
- The exam terminal already has `alias k=kubectl` set. Practice using it from day one.
- Use `kubectl explain <resource>.<field>` instead of memorizing YAML structure.
- Use `kubectl run --dry-run=client -o yaml` to generate Pod/Deployment stubs quickly.
- Always verify your work: `kubectl get`, `kubectl describe`, `kubectl logs`.

---