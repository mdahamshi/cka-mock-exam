# CKA Mock Exam — Mohammad Dahamshi
## Kubernetes v1.34 | 17 Questions | 120 Minutes
### Cluster: cp (control-plane), node01, node02

---

> **Before you start:**
> ```bash
> source ~/.bashrc   # loads: alias k=kubectl, $do, $now, completion
> ```
> Work in the correct node for each question. Always `exit` back to your
> main terminal before switching nodes.
> **Passing score: 66%**

---

## Question 1 | Kubeconfig Contexts (4%)
**Node: `cp` (control plane)**

A kubeconfig file has been placed at `/opt/course/1/kubeconfig`.

Perform the following tasks:

1. Write **all context names** from that kubeconfig into `/opt/course/1/contexts` (one per line).
2. Write the **current context name** into `/opt/course/1/current-context`.
3. Find the `client-certificate-data` of user **`account-0027@internal`**, **base64-decode** it,
   and write the decoded certificate into `/opt/course/1/cert`.

---

## Question 2 | PersistentVolume, PVC, Pod (7%)
**Node: `cp`**

1. Create a **PersistentVolume** named `safari-pv` with:
   - Capacity: `2Gi`
   - AccessMode: `ReadWriteOnce`
   - HostPath: `/mnt/data`
   - **No** `storageClassName`

2. Create a **PersistentVolumeClaim** named `safari-pvc` in Namespace `project-t230`:
   - Requests: `2Gi`
   - AccessMode: `ReadWriteOnce`
   - **No** `storageClassName` (must bind to `safari-pv`)

3. Create a **Pod** named `safari` in Namespace `project-t230`:
   - Image: `nginx:1-alpine`
   - Mounts the PVC at `/tmp/safari-data`

Verify the Pod is `Running` and the PVC is `Bound`.

---

## Question 3 | Scale StatefulSet (3%)
**Node: `cp`**

There is a **StatefulSet** named `o3db` in Namespace `project-h800` currently running 2 replicas.

Scale it down to **1 replica**.

---

## Question 4 | QoS – Identify Pods Terminated First (5%)
**Node: `cp`**

Check all Pods in Namespace `project-c13`.

Find the Pod(s) that would be **terminated first** when the node runs out of resources
(i.e., BestEffort QoS class — no resource requests/limits set).

Write the names of those Pod(s) into `/opt/course/4/pods-terminated-first.txt` (one per line).

---

## Question 5 | RBAC – ServiceAccount, Role, RoleBinding (6%)
**Node: `cp`**

In Namespace `project-hamster`:

1. Create a **ServiceAccount** named `processor`.
2. Create a **Role** named `processor` that allows:
   - `create` on `secrets`
   - `create` on `configmaps`
3. Create a **RoleBinding** named `processor` that binds the Role to the ServiceAccount.

Verify with:
```bash
k -n project-hamster auth can-i create secrets --as system:serviceaccount:project-hamster:processor
```

---

## Question 6 | DaemonSet on All Nodes (5%)
**Node: `cp`**

In Namespace `project-tiger`, create a **DaemonSet** named `ds-important`:

- Image: `httpd:2-alpine`
- Labels on both DaemonSet and Pods: `id=ds-important`, `uuid=18426a0b-5f59-4e10-923f-c0e078e82462`
- Pod resource requests: `10m` CPU and `10Mi` memory
- Pods **must run on ALL nodes**, including the control-plane

> **Hint:** You'll need to tolerate control-plane taints.

---

## Question 7 | NetworkPolicy (7%)
**Node: `cp`**

In Namespace `project-snake`, create a **NetworkPolicy** named `np-backend`:

Allow **backend-\*** Pods to:
- Connect to **db1-\*** Pods on **port 1111**
- Connect to **db2-\*** Pods on **port 2222**

The policy must **deny all other egress** from backend Pods (including to `vault`).

> Use `app` label selectors. Existing Pods: `backend`, `db1`, `db2`, `vault` — all in `project-snake`.

---

## Question 8 | Deployment with Pod Spread / Topology (6%)
**Node: `cp`**

In Namespace `project-tiger`, create a **Deployment** named `deploy-important`:

- **3 replicas**
- Labels on Deployment and Pods: `id=very-important`
- Container 1: name `container1`, image `nginx:1-alpine`
- Container 2: name `container2`, image `registry.k8s.io/pause:3.10`
- Use **`topologySpreadConstraints`** (or `podAntiAffinity`) so that
  **at most 1 Pod runs per node** — if there are only 2 nodes, 1 Pod will be `Pending` (that is acceptable).

---

## Question 9 | Contact the Kubernetes API from inside a Pod (5%)
**Node: `cp`**

In Namespace `project-swan`, a ServiceAccount `secret-reader` already exists with permissions
to list Secrets.

1. Create a **Pod** named `api-contact` using image `nginx:1-alpine` and ServiceAccount `secret-reader`.
2. `exec` into the Pod and use `curl` to **manually query the Kubernetes API**
   to list all Secrets in Namespace `project-swan`.
3. Write the **JSON response** into `/opt/course/9/result.json` on the `cp` node.

> **Hint:** The API server is at `https://kubernetes.default.svc` inside the cluster.
> The token is at `/var/run/secrets/kubernetes.io/serviceaccount/token`.
> The CA is at `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`.

---

## Question 10 | CoreDNS Configuration (4%)
**Node: `cp`**

1. **Backup** the current CoreDNS ConfigMap to `/opt/course/16/coredns_backup.yaml`.
2. Edit the CoreDNS ConfigMap so that DNS queries for `*.cluster.local` also resolve via
   a **secondary upstream**: add `forward . 8.8.8.8` to the `Corefile`'s default block
   (keep the existing `forward . /etc/resolv.conf` as well, or replace it).
3. Restart CoreDNS pods to apply the change.

> **Verify:** `kubectl -n kube-system rollout status deployment coredns`

---

## Question 11 | Node Selector / Taint Scheduling (4%)
**Node: `cp`**

`node01` has been labeled `disk=ssd`.

1. Create a Pod named `fast-storage` in the `default` namespace:
   - Image: `nginx:1-alpine`
   - Use a `nodeSelector` to **schedule it only on nodes with `disk=ssd`**

2. Taint `node02` with `env=production:NoSchedule`.
3. Create a second Pod named `tolerate-prod` in the `default` namespace:
   - Image: `nginx:1-alpine`
   - Must run on `node02` — add the appropriate **toleration**.

---

## Question 12 | Cluster Upgrade — Worker Node (8%)
**Node: `cp`, then `node01`**

`node01` is running an **older patch version** of Kubernetes than the control-plane.

1. Drain `node01` gracefully (ignore DaemonSets).
2. On `node01`, upgrade `kubeadm`, then upgrade the node's Kubernetes components
   to **match the control-plane version exactly**.
3. Upgrade `kubelet` and `kubectl` on `node01`.
4. Uncordon `node01` and verify it shows `Ready`.

> **Hint:** Use `apt-cache madison kubeadm` to find the exact package version.

---

## Question 13 | Troubleshoot Broken Application (8%)
**Node: `cp`**

In Namespace `project-fault`, a Deployment named `app-broken` is failing,
and its Service `app-broken-svc` does not route traffic correctly.

Find and fix **both** issues so that:
- All 3 Pods are `Running`
- `curl`-ing the Service ClusterIP on port 80 returns an HTTP response

> **Hints:**
> - Check Pod events for image issues.
> - Check Service `selector` vs Pod labels.

---

## Question 14 | etcd Backup & Restore (8%)
**Node: `cp`**

1. Create an etcd snapshot and save it to `/opt/course/etcd-backup/etcd-snapshot.db`.
   Use `etcdctl` with the correct certificates (check the etcd static pod manifest).

2. Verify the snapshot is valid:
   ```bash
   ETCDCTL_API=3 etcdctl snapshot status /opt/course/etcd-backup/etcd-snapshot.db --write-out=table
   ```

3. Write the command used to take the backup into `/opt/course/etcd-backup/backup-command.txt`.

> **Hint:** Check `/etc/kubernetes/manifests/etcd.yaml` for cert paths and endpoints.

---

## Question 15 | Ingress (5%)
**Node: `cp`**

In Namespace `project-r500`:
- A Deployment `web-app` and Service `web-app-svc` (port 80) already exist.

1. Check whether an **IngressClass** is available on the cluster.
2. Create an **Ingress** named `web-ingress` that routes:
   - `Host: web.local` → `web-app-svc` on port `80`
   - Path: `/` (pathType: `Prefix`)
3. Verify the Ingress is created and has an address assigned (may take a moment).

---

## Question 16 | Certificate Expiration (4%)
**Node: `cp`**

1. Find the expiration date of the **kube-apiserver serving certificate** using `openssl`:
   ```bash
   openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
   ```
2. Write the `notAfter` date into `/opt/course/16/expiration`.
3. Also run `kubeadm certs check-expiration` and confirm both show the same date.
4. Write the full `kubeadm` command used (step 3) into `/opt/course/16/kubeadm-command.txt`.

---

## Question 17 | Kustomize + HPA (7%)
**Node: `cp`**

The `api-gateway` application uses a Kustomize overlay structure at `/opt/course/17/api-gateway/`.

1. Add a **HorizontalPodAutoscaler** resource to the `base` layer:
   - Name: `api-gateway-hpa`
   - MinReplicas: `1`, MaxReplicas: `4`
   - Target CPU utilization: `70%`
   - Targets the `api-gateway` Deployment

2. Apply the **staging** overlay:
   ```bash
   kubectl kustomize /opt/course/17/api-gateway/staging | kubectl apply -f -
   ```

3. Apply the **prod** overlay:
   ```bash
   kubectl kustomize /opt/course/17/api-gateway/prod | kubectl apply -f -
   ```

4. Verify both namespaces have the Deployment and HPA running:
   ```bash
   k -n api-gateway-staging get deploy,hpa
   k -n api-gateway-prod    get deploy,hpa
   ```

---

# Answer Key

<details>
<summary>Click to expand — try yourself first!</summary>

## A1 | Kubeconfig Contexts
```bash
k --kubeconfig /opt/course/1/kubeconfig config get-contexts -oname \
  > /opt/course/1/contexts

k --kubeconfig /opt/course/1/kubeconfig config current-context \
  > /opt/course/1/current-context

k --kubeconfig /opt/course/1/kubeconfig config view --raw \
  -o jsonpath='{.users[?(@.name=="account-0027@internal")].user.client-certificate-data}' \
  | base64 -d > /opt/course/1/cert
```

---

## A2 | PV / PVC / Pod
```yaml
# safari-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: safari-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data
---
# safari-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: safari-pvc
  namespace: project-t230
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
# safari-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: safari
  namespace: project-t230
spec:
  containers:
  - name: main
    image: nginx:1-alpine
    volumeMounts:
    - mountPath: /tmp/safari-data
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: safari-pvc
```

---

## A3 | Scale StatefulSet
```bash
k -n project-h800 scale sts o3db --replicas 1
```

---

## A4 | QoS
```bash
# Find pods with no resource requests (BestEffort = terminated first)
k -n project-c13 get pod -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'
# Pods from c13-runner-heavy have empty resources {} -> write to file
k -n project-c13 get pod --no-headers | grep runner-heavy | awk '{print $1}' \
  > /opt/course/4/pods-terminated-first.txt
```

---

## A5 | RBAC
```bash
k -n project-hamster create sa processor
k -n project-hamster create role processor \
  --verb=create --resource=secrets,configmaps
k -n project-hamster create rolebinding processor \
  --role=processor --serviceaccount=project-hamster:processor
```

---

## A6 | DaemonSet
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ds-important
  namespace: project-tiger
  labels:
    id: ds-important
    uuid: 18426a0b-5f59-4e10-923f-c0e078e82462
spec:
  selector:
    matchLabels:
      id: ds-important
  template:
    metadata:
      labels:
        id: ds-important
        uuid: 18426a0b-5f59-4e10-923f-c0e078e82462
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: main
        image: httpd:2-alpine
        resources:
          requests:
            cpu: 10m
            memory: 10Mi
```

---

## A7 | NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-backend
  namespace: project-snake
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db1
    ports:
    - port: 1111
  - to:
    - podSelector:
        matchLabels:
          app: db2
    ports:
    - port: 2222
```

---

## A8 | Deployment with Spread
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-important
  namespace: project-tiger
  labels:
    id: very-important
spec:
  replicas: 3
  selector:
    matchLabels:
      id: very-important
  template:
    metadata:
      labels:
        id: very-important
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            id: very-important
      containers:
      - name: container1
        image: nginx:1-alpine
      - name: container2
        image: registry.k8s.io/pause:3.10
```

---

## A9 | API from inside Pod
```bash
# Create Pod
k -n project-swan run api-contact --image=nginx:1-alpine \
  --serviceaccount=secret-reader $do > /tmp/api-contact.yaml
# edit if needed, then apply
k apply -f /tmp/api-contact.yaml

# Exec and curl
k -n project-swan exec api-contact -- sh -c '
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  curl -sk --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    -H "Authorization: Bearer $TOKEN" \
    https://kubernetes.default.svc/api/v1/namespaces/project-swan/secrets
' > /opt/course/9/result.json
```

---

## A10 | CoreDNS
```bash
# Backup
k -n kube-system get cm coredns -o yaml > /opt/course/16/coredns_backup.yaml

# Edit (add 8.8.8.8 to forward line or add a second forward)
k -n kube-system edit cm coredns
# Change: forward . /etc/resolv.conf
# To:     forward . /etc/resolv.conf 8.8.8.8

# Restart
k -n kube-system rollout restart deployment coredns
k -n kube-system rollout status deployment coredns
```

---

## A11 | Node Selector / Taint
```bash
# Pod with nodeSelector
k run fast-storage --image=nginx:1-alpine $do > /tmp/fast.yaml
# add nodeSelector: disk: ssd under spec
k apply -f /tmp/fast.yaml

# Taint node02
k taint node node02 env=production:NoSchedule

# Pod with toleration
k run tolerate-prod --image=nginx:1-alpine $do > /tmp/tol.yaml
# add tolerations block + nodeName: node02
k apply -f /tmp/tol.yaml
```

---

## A12 | Cluster Upgrade Worker Node
```bash
# On cp:
k drain node01 --ignore-daemonsets --delete-emptydir-data

# On node01:
ssh node01
KUBE_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | sed 's/v//')
# or check on cp: kubectl get nodes cp -o jsonpath='{.status.nodeInfo.kubeletVersion}'

sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=<VERSION>
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node

sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=<VERSION> kubectl=<VERSION>
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
exit

# Back on cp:
k uncordon node01
k get nodes
```

---

## A13 | Troubleshoot Broken App
```bash
# Issue 1: wrong image
k -n project-fault set image deployment/app-broken main=nginx:1-alpine

# Issue 2: service selector mismatch
k -n project-fault edit svc app-broken-svc
# Change selector: app: app-broken-WRONG-LABEL -> app: app-broken

# Verify
k -n project-fault get pods
k -n project-fault get ep app-broken-svc
```

---

## A14 | etcd Backup
```bash
# Get cert paths from etcd manifest
cat /etc/kubernetes/manifests/etcd.yaml | grep -E 'cert|key|trusted'

ETCDCTL_API=3 etcdctl snapshot save /opt/course/etcd-backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

ETCDCTL_API=3 etcdctl snapshot status /opt/course/etcd-backup/etcd-snapshot.db --write-out=table

echo "ETCDCTL_API=3 etcdctl snapshot save /opt/course/etcd-backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key" > /opt/course/etcd-backup/backup-command.txt
```

---

## A15 | Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: project-r500
spec:
  rules:
  - host: web.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-svc
            port:
              number: 80
```
> If no IngressClass exists, the Ingress may stay without address. Check `k get ingressclass`.

---

## A16 | Certificate Expiry
```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates \
  | grep notAfter | cut -d= -f2 > /opt/course/16/expiration

echo "kubeadm certs check-expiration" > /opt/course/16/kubeadm-command.txt
kubeadm certs check-expiration
```

---

## A17 | Kustomize + HPA
```yaml
# /opt/course/17/api-gateway/base/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```
```bash
# Add hpa.yaml to base kustomization.yaml resources list, then:
kubectl kustomize /opt/course/17/api-gateway/staging | kubectl apply -f -
kubectl kustomize /opt/course/17/api-gateway/prod    | kubectl apply -f -
k -n api-gateway-staging get deploy,hpa
k -n api-gateway-prod    get deploy,hpa
```

</details>

---


