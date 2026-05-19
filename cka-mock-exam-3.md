# CKA Mock Exam 3 — Mohammad Dahamshi
## Kubernetes 1.35 | 17 Questions | 120 Minutes | Post-Feb 2025 Curriculum
### Cluster: cp (control-plane), node01, node02

---

> **Before you start:**
> ```bash
> source ~/.bashrc   # loads: alias k=kubectl, $do, $now, completion
> ```
> **Q6 requires breaking the apiserver first — read it before you start the timer.**
> **Passing score: 66%**

---

## Question 1 | Helm — Template + Install (6%)
**Node: `cp`**

A `bitnami` Helm repo is already configured.

1. Search for the `nginx` chart in the bitnami repo and find the **latest version**.

2. Generate a Helm template for `bitnami/nginx` with release name `web-server`
   in namespace `helm-lab`, and save the rendered YAML to `/opt/course/1/helm-template.yaml`.

3. Install the chart with:
   - Release name: `web-server`
   - Namespace: `helm-lab`
   - Set `replicaCount=2`
   - Set `service.type=ClusterIP`

4. Verify the release is deployed:
   ```bash
   helm -n helm-lab list
   kubectl -n helm-lab get pods
   ```

> **Hint:** `helm template <release> <chart> -n <ns> > file.yaml`
> then `helm install <release> <chart> -n <ns> --set key=val`

---

## Question 2 | Gateway API — Migrate Ingress to Gateway + HTTPRoute (8%)
**Node: `cp`**

In Namespace `gateway-lab`, an `Ingress` named `web-ingress` currently routes traffic
for host `web.local` → Service `web-backend-svc` on port 80.
A TLS secret `web-tls` already exists in the namespace.

**Tasks:**

1. Check if Gateway API CRDs are installed:
   ```bash
   kubectl get crd | grep gateway
   ```
   If not present, install them:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
   ```

2. Check available `GatewayClass`:
   ```bash
   kubectl get gatewayclass
   ```

3. Create a **Gateway** named `web-gateway` in `gateway-lab`:
   - GatewayClassName: use the available one (or `nginx` if none)
   - Listener: HTTPS on port 443, hostname `web.local`
   - TLS mode: `Terminate`, certificateRef: `web-tls`

4. Create an **HTTPRoute** named `web-route` in `gateway-lab`:
   - Attach to `web-gateway`
   - Match hostname `web.local`, path prefix `/`
   - Backend: `web-backend-svc` port 80

5. **Delete** the old `web-ingress` Ingress.

6. Verify:
   ```bash
   kubectl -n gateway-lab get gateway,httproute
   kubectl -n gateway-lab describe httproute web-route
   ```

---

## Question 3 | PriorityClass (5%)
**Node: `cp`**

A PriorityClass `background-tasks` (value `100`) already exists in the cluster.

1. Create a new **PriorityClass** named `high-priority` with:
   - Value: `1000000`
   - `globalDefault: false`
   - Description: `"High priority for critical workloads"`
   - `preemptionPolicy: PreemptLowerPriority`

2. Update the Deployment `api-server` in Namespace `priority-lab` to use
   `priorityClassName: high-priority`.

3. Verify the pods are restarted and running with the new priority:
   ```bash
   kubectl -n priority-lab get pod -o jsonpath='{.items[0].spec.priorityClassName}'
   ```

---

## Question 4 | Sidecar Log Container (6%)
**Node: `cp`**

The Deployment `app-logger` in Namespace `logging-lab` has a single container `main`
(nginx) that writes access logs to `/var/log/nginx/access.log`.

Add a **sidecar container** named `log-reader` to the Deployment:
- Image: `busybox:1`
- Command: `tail -f /var/log/nginx/access.log`
- Share the log directory with the main container via an `emptyDir` volume mounted at `/var/log/nginx`

After updating:
- Verify both containers are running in the same Pod
- Check the sidecar logs:
  ```bash
  kubectl -n logging-lab logs deploy/app-logger -c log-reader
  ```

> **Hint:** `kubectl -n logging-lab edit deployment app-logger`
> Add the volume, volumeMount to both containers, and the sidecar container.

---

## Question 5 | ConfigMap — Enable TLSv1.2 + TLSv1.3 (4%)
**Node: `cp`**

In Namespace `nginx-lab`, the ConfigMap `nginx-config` currently configures nginx
to use **only TLSv1.3**.

Update the ConfigMap so nginx accepts both **TLSv1.2 and TLSv1.3**:
- Change the `ssl_protocols` line from `TLSv1.3` to `TLSv1.2 TLSv1.3`

After editing, rollout restart the `nginx-tls` Deployment and verify:
```bash
kubectl -n nginx-lab rollout restart deployment nginx-tls
kubectl -n nginx-lab exec deploy/nginx-tls -- nginx -T 2>/dev/null | grep ssl_protocols
```

---

## Question 6 | Troubleshoot Broken kube-apiserver (8%)
**Node: `cp`**

> **⚠️ Break the cluster BEFORE starting your timer:**
> ```bash
> sudo sed -i 's/--etcd-servers=https:\/\/127.0.0.1:2379/--etcd-servers=https:\/\/127.0.0.1:1234/' \
>   /etc/kubernetes/manifests/kube-apiserver.yaml
> # Wait ~30s then confirm it's broken:
> kubectl get nodes   # should fail
> ```

The kube-apiserver is not starting. The kubelet log shows it is crashing.

1. Investigate why the kube-apiserver static pod is failing.
   Check: `crictl ps -a`, `crictl logs <container-id>`, the manifest at
   `/etc/kubernetes/manifests/kube-apiserver.yaml`

2. Identify the incorrect parameter and fix it.

3. Wait for the apiserver to recover and verify:
   ```bash
   kubectl get nodes   # all Ready
   kubectl -n kube-system get pod | grep apiserver
   ```

> **Hint:** The backup of the original manifest is at `/opt/course/6/kube-apiserver-backup.yaml`
> Check the `--etcd-servers` flag — the port should be `2379` not `1234`.

---

## Question 7 | NetworkPolicy — Multi-tier App (6%)
**Node: `cp`**

In Namespace `netpol-lab`, three Deployments exist:
- `frontend` (label `app: frontend`)
- `backend-api` (label `app: backend-api`) — Service `backend-api-svc` on port 8080
- `cache` (label `app: cache`) — Service `cache-svc` on port 6379

Create **two NetworkPolicies**:

**Policy 1** — `allow-frontend-to-backend`:
- Allow `frontend` pods to reach `backend-api` pods on port **8080**
- Deny all other ingress to `backend-api`

**Policy 2** — `allow-backend-to-cache`:
- Allow `backend-api` pods to reach `cache` pods on port **6379**
- Deny all other ingress to `cache`

Verify:
```bash
kubectl -n netpol-lab get networkpolicy
```

---

## Question 8 | StorageClass + PVC + Pod (6%)
**Node: `cp`**

In Namespace `storage-lab`:

**Part A — Match existing PV:**
A PV `existing-pv` already exists with:
- Capacity: `1Gi`, AccessMode: `ReadWriteOnce`, StorageClass: `manual`

Create a **PVC** named `manual-pvc` that binds to it, then create a Pod named `pv-pod`
that mounts it at `/data`.

**Part B — Dynamic provisioning:**
1. Create a **StorageClass** named `fast-local`:
   - Provisioner: `rancher.io/local-path`
   - `reclaimPolicy: Delete`
   - `volumeBindingMode: WaitForFirstConsumer`

2. Create a **PVC** named `dynamic-pvc` requesting `500Mi` using `fast-local`.

3. Create a Pod named `dynamic-pod` (image `nginx:1-alpine`) that mounts `dynamic-pvc` at `/cache`.

Verify both PVCs are `Bound`:
```bash
kubectl -n storage-lab get pvc,pv
```

---

## Question 9 | Pod Disruption Budget (4%)
**Node: `cp`**

The Deployment `critical-app` in Namespace `pdb-lab` has 4 replicas.

1. Create a **PodDisruptionBudget** named `critical-app-pdb` that ensures:
   - **At least 3 pods** are always available during voluntary disruptions
   - Target: pods with label `app: critical-app`

2. Verify the PDB:
   ```bash
   kubectl -n pdb-lab get pdb
   kubectl -n pdb-lab describe pdb critical-app-pdb
   ```

3. Attempt to drain `node01` and observe whether the PDB blocks it
   (it should block once only 3 pods remain on schedulable nodes):
   ```bash
   kubectl drain node01 --ignore-daemonsets --dry-run
   ```
   Uncordon afterwards: `kubectl uncordon node01`

---

## Question 10 | CronJob + Job (5%)
**Node: `cp`**

In Namespace `batch-lab`:

1. Create a **CronJob** named `db-backup`:
   - Schedule: every 5 minutes (`*/5 * * * *`)
   - Image: `busybox:1`
   - Command: `sh -c "echo Backup started at $(date) && sleep 10 && echo Done"`
   - `restartPolicy: OnFailure`
   - `successfulJobsHistoryLimit: 3`
   - `failedJobsHistoryLimit: 1`
   - Deadline: if a job hasn't started within 10 seconds, skip it (`startingDeadlineSeconds: 10`)

2. Manually trigger a Job from the CronJob immediately:
   ```bash
   kubectl -n batch-lab create job db-backup-manual --from=cronjob/db-backup
   ```

3. Wait for the Job to complete and check its logs:
   ```bash
   kubectl -n batch-lab get jobs
   kubectl -n batch-lab logs job/db-backup-manual
   ```

---

## Question 11 | Troubleshoot Broken Service (5%)
**Node: `cp`**

In Namespace `trouble-lab`, a Deployment `payment-service` is running but requests
to Service `payment-svc` are not reaching any pods — `kubectl get endpoints` shows none.

Find and fix **both** bugs in the Service so that:
- The Service selector matches the Deployment pods
- `curl <ClusterIP>:8080` returns a response from nginx

Verify:
```bash
kubectl -n trouble-lab get endpoints payment-svc
kubectl -n trouble-lab run test --image=busybox:1 --rm -it --restart=Never \
  -- wget -qO- http://payment-svc:8080
```

> **Hint:** Compare `kubectl -n trouble-lab describe svc payment-svc` selector
> vs `kubectl -n trouble-lab get pods --show-labels`
> Also check the `targetPort` vs what port the container actually listens on.

---

## Question 12 | RBAC — ClusterRole Aggregation (5%)
**Node: `cp`**

A ClusterRole `pod-reader-base` exists with label
`rbac.example.com/aggregate-to-monitoring: "true"`.
A ServiceAccount `monitoring-sa` exists in Namespace `rbac-lab`.

1. Create an **aggregated ClusterRole** named `monitoring-role`:
   - Use `aggregationRule` to automatically aggregate all ClusterRoles
     with label `rbac.example.com/aggregate-to-monitoring: "true"`
   - No explicit `rules` — they come from aggregation

2. Create a **ClusterRoleBinding** named `monitoring-binding`:
   - Binds `monitoring-role` to ServiceAccount `monitoring-sa` in `rbac-lab`

3. Verify the aggregated permissions work:
   ```bash
   kubectl auth can-i list pods \
     --as system:serviceaccount:rbac-lab:monitoring-sa
   ```
   Should return `yes`.

---

## Question 13 | Deployment Rollout + Rollback (5%)
**Node: `cp`**

In Namespace `rollout-lab`, Deployment `web-app` has 3 revisions.
The latest (revision 3) uses a broken image tag and pods are stuck in `ImagePullBackOff`.

1. Check the rollout history:
   ```bash
   kubectl -n rollout-lab rollout history deployment web-app
   ```

2. Roll back to **revision 2** (the last working version):
   ```bash
   kubectl -n rollout-lab rollout undo deployment web-app --to-revision=2
   ```

3. Verify all 3 pods are `Running` and confirm the image:
   ```bash
   kubectl -n rollout-lab get pods
   kubectl -n rollout-lab describe deployment web-app | grep Image
   ```

4. Scale the deployment to **5 replicas** and confirm.

---

## Question 14 | Init Container (5%)
**Node: `cp`**

In Namespace `init-lab`, create a Pod named `init-pod`:

- **Init container** named `setup`:
  - Image: `busybox:1`
  - Command: `sh -c "echo Initialized > /work/init.txt && sleep 2"`
  - Volume mount: `work-vol` at `/work`

- **Main container** named `main`:
  - Image: `nginx:1-alpine`
  - Volume mount: `work-vol` at `/work` (read-only)
  - **ReadinessProbe**: exec `cat /work/init.txt`

- Shared `emptyDir` volume named `work-vol`

Verify:
```bash
kubectl -n init-lab get pod init-pod   # should be 1/1 Running
kubectl -n init-lab exec init-pod -- cat /work/init.txt   # should print "Initialized"
```

---

## Question 15 | Node Drain + PDB (5%)
**Node: `cp`**

In Namespace `drain-lab`:
- Deployment `ha-app` has 3 replicas
- PDB `ha-app-pdb` requires `minAvailable: 2`

**Tasks:**

1. Drain `node01` gracefully. The PDB should allow draining since enough replicas
   can stay on `cp` and `node02`:
   ```bash
   kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
   ```

2. Verify `node01` is `SchedulingDisabled` and all `ha-app` pods are still running.

3. Write the node status into `/opt/course/15/node-status.txt`:
   ```bash
   kubectl get node node01 > /opt/course/15/node-status.txt
   ```

4. Uncordon `node01` and verify pods rebalance:
   ```bash
   kubectl uncordon node01
   ```

---

## Question 16 | ResourceQuota + LimitRange (5%)
**Node: `cp`**

A `ResourceQuota` named `compute-quota` already exists in Namespace `quota-lab`
limiting: 5 pods, 1 CPU request, 512Mi memory request.

1. Add a **LimitRange** named `default-limits` in `quota-lab`:
   - Default CPU request: `100m`, limit: `200m`
   - Default memory request: `64Mi`, limit: `128Mi`
   - Type: `Container`

2. Create a Pod named `quota-test` (image `nginx:1-alpine`) in `quota-lab`
   **without** specifying any resource requests or limits.

3. Verify the LimitRange injected defaults:
   ```bash
   kubectl -n quota-lab describe pod quota-test | grep -A5 Limits
   ```

4. Write the namespace resource usage into `/opt/course/16/quota-status.txt`:
   ```bash
   kubectl -n quota-lab describe resourcequota compute-quota \
     > /opt/course/16/quota-status.txt
   ```

---

## Question 17 | Helm Template Save + Kustomize Patch (7%)
**Node: `cp`**

**Part A — Helm:**

1. Generate a Helm template for `bitnami/nginx` release `nginx-prod`
   in namespace `deploy-lab` with `replicaCount=3`:
   ```bash
   helm template nginx-prod bitnami/nginx \
     -n deploy-lab \
     --set replicaCount=3 \
     > /opt/course/17/nginx-helm-template.yaml
   ```

2. Install the chart from the saved template file:
   ```bash
   kubectl apply -f /opt/course/17/nginx-helm-template.yaml
   ```

**Part B — Kustomize:**

A Kustomize structure exists at `/opt/course/17/app/`:
- `base/`: Deployment `myapp` with 1 replica
- `prod/`: Overlay — sets namespace to `deploy-lab`, patches replicas to 3

1. Apply the `prod` overlay:
   ```bash
   kubectl kustomize /opt/course/17/app/prod | kubectl apply -f -
   ```

2. Verify:
   ```bash
   kubectl -n deploy-lab get deploy myapp   # should show 3/3
   ```

3. Add an additional patch to `prod/kustomization.yaml` that changes the
   container image to `nginx:1.25-alpine`, then re-apply.

---

# Answer Key

<details>
<summary>Click to expand — try it yourself first!</summary>

## A1 | Helm

```bash
helm search repo bitnami/nginx

# Generate template
helm template web-server bitnami/nginx \
  -n helm-lab \
  --set replicaCount=2 \
  --set service.type=ClusterIP \
  > /opt/course/1/helm-template.yaml

# Install
helm install web-server bitnami/nginx \
  -n helm-lab \
  --set replicaCount=2 \
  --set service.type=ClusterIP

helm -n helm-lab list
kubectl -n helm-lab get pods
```

---

## A2 | Gateway API

```bash
# Install CRDs if missing
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl get gatewayclass
```

```yaml
# gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: gateway-lab
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: web.local
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: web-tls
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
  namespace: gateway-lab
spec:
  parentRefs:
  - name: web-gateway
  hostnames:
  - web.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web-backend-svc
      port: 80
```
```bash
kubectl apply -f gateway.yaml
kubectl -n gateway-lab delete ingress web-ingress
kubectl -n gateway-lab get gateway,httproute
```

---

## A3 | PriorityClass

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "High priority for critical workloads"
```
```bash
kubectl apply -f priorityclass.yaml
kubectl -n priority-lab patch deployment api-server \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
kubectl -n priority-lab get pod -o jsonpath='{.items[0].spec.priorityClassName}'
```

---

## A4 | Sidecar

```bash
kubectl -n logging-lab edit deployment app-logger
```
Add to the Pod spec:
```yaml
      volumes:
      - name: log-vol
        emptyDir: {}
      containers:
      - name: main
        image: nginx:1-alpine
        volumeMounts:
        - name: log-vol
          mountPath: /var/log/nginx
      - name: log-reader
        image: busybox:1
        command: ["sh", "-c", "tail -f /var/log/nginx/access.log"]
        volumeMounts:
        - name: log-vol
          mountPath: /var/log/nginx
```
```bash
kubectl -n logging-lab rollout status deployment app-logger
kubectl -n logging-lab logs deploy/app-logger -c log-reader
```

---

## A5 | ConfigMap TLS

```bash
kubectl -n nginx-lab edit cm nginx-config
# Change:  ssl_protocols TLSv1.3;
# To:      ssl_protocols TLSv1.2 TLSv1.3;

kubectl -n nginx-lab rollout restart deployment nginx-tls
kubectl -n nginx-lab rollout status deployment nginx-tls
kubectl -n nginx-lab exec deploy/nginx-tls -- nginx -T 2>/dev/null | grep ssl_protocols
```

---

## A6 | kube-apiserver fix

```bash
sudo -i
crictl ps -a | grep apiserver   # find the container
crictl logs <container-id> | tail -20
# See: "connection refused" or "no such host" for etcd endpoint

# Fix the manifest
grep etcd-servers /etc/kubernetes/manifests/kube-apiserver.yaml
# Shows: --etcd-servers=https://127.0.0.1:1234  <- wrong

sed -i 's/--etcd-servers=https:\/\/127.0.0.1:1234/--etcd-servers=https:\/\/127.0.0.1:2379/' \
  /etc/kubernetes/manifests/kube-apiserver.yaml

# Wait ~30s for kubelet to restart the apiserver
watch crictl ps | grep apiserver   # wait until Running
kubectl get nodes   # should work again
```

---

## A7 | NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-cache
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: cache
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend-api
    ports:
    - port: 6379
```

---

## A8 | StorageClass + PVC + Pod

```yaml
# Part A - manual PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: manual-pvc
  namespace: storage-lab
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
---
# Part A - pod
apiVersion: v1
kind: Pod
metadata:
  name: pv-pod
  namespace: storage-lab
spec:
  containers:
  - name: main
    image: nginx:1-alpine
    volumeMounts:
    - mountPath: /data
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: manual-pvc
---
# Part B - StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-local
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
# Part B - dynamic PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
  namespace: storage-lab
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: fast-local
  resources:
    requests:
      storage: 500Mi
---
# Part B - pod
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-pod
  namespace: storage-lab
spec:
  containers:
  - name: main
    image: nginx:1-alpine
    volumeMounts:
    - mountPath: /cache
      name: cache
  volumes:
  - name: cache
    persistentVolumeClaim:
      claimName: dynamic-pvc
```

---

## A9 | PDB

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-app-pdb
  namespace: pdb-lab
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: critical-app
```
```bash
kubectl apply -f pdb.yaml
kubectl -n pdb-lab get pdb
kubectl drain node01 --ignore-daemonsets --dry-run
kubectl uncordon node01
```

---

## A10 | CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
  namespace: batch-lab
spec:
  schedule: "*/5 * * * *"
  startingDeadlineSeconds: 10
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox:1
            command:
            - sh
            - -c
            - echo "Backup started at $(date) && sleep 10 && echo Done"
          restartPolicy: OnFailure
```
```bash
kubectl apply -f cronjob.yaml
kubectl -n batch-lab create job db-backup-manual --from=cronjob/db-backup
kubectl -n batch-lab get jobs
kubectl -n batch-lab logs job/db-backup-manual
```

---

## A11 | Broken Service

```bash
# Check endpoints - empty
kubectl -n trouble-lab get endpoints payment-svc

# Check pod labels
kubectl -n trouble-lab get pods --show-labels
# Pods have: app=payment, tier=backend

# Check service selector
kubectl -n trouble-lab describe svc payment-svc | grep Selector
# Shows: app=payment, tier=frontend  <- WRONG

# Fix both bugs
kubectl -n trouble-lab edit svc payment-svc
# 1. selector.tier: frontend -> backend
# 2. targetPort: 9090 -> 80

# Verify
kubectl -n trouble-lab get endpoints payment-svc   # should show pod IPs
```

---

## A12 | RBAC Aggregation

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-role
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: []
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-binding
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: rbac-lab
roleRef:
  kind: ClusterRole
  name: monitoring-role
  apiGroup: rbac.authorization.k8s.io
```
```bash
kubectl apply -f monitoring-rbac.yaml
kubectl auth can-i list pods \
  --as system:serviceaccount:rbac-lab:monitoring-sa   # -> yes
```

---

## A13 | Rollout Rollback

```bash
kubectl -n rollout-lab rollout history deployment web-app

# Roll back to revision 2
kubectl -n rollout-lab rollout undo deployment web-app --to-revision=2
kubectl -n rollout-lab rollout status deployment web-app

# Verify image
kubectl -n rollout-lab describe deployment web-app | grep Image
# Should show nginx:1.25-alpine

# Scale to 5
kubectl -n rollout-lab scale deployment web-app --replicas=5
kubectl -n rollout-lab get pods
```

---

## A14 | Init Container

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-pod
  namespace: init-lab
spec:
  volumes:
  - name: work-vol
    emptyDir: {}
  initContainers:
  - name: setup
    image: busybox:1
    command: ["sh", "-c", "echo Initialized > /work/init.txt && sleep 2"]
    volumeMounts:
    - name: work-vol
      mountPath: /work
  containers:
  - name: main
    image: nginx:1-alpine
    readinessProbe:
      exec:
        command: ["cat", "/work/init.txt"]
    volumeMounts:
    - name: work-vol
      mountPath: /work
      readOnly: true
```
```bash
kubectl apply -f init-pod.yaml
kubectl -n init-lab get pod init-pod
kubectl -n init-lab exec init-pod -- cat /work/init.txt
```

---

## A15 | Drain + PDB

```bash
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
kubectl get node node01   # SchedulingDisabled
kubectl -n drain-lab get pods -o wide   # all still Running

kubectl get node node01 > /opt/course/15/node-status.txt

kubectl uncordon node01
kubectl get nodes
```

---

## A16 | ResourceQuota + LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: quota-lab
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 128Mi
    defaultRequest:
      cpu: 100m
      memory: 64Mi
```
```bash
kubectl apply -f limitrange.yaml
kubectl -n quota-lab run quota-test --image=nginx:1-alpine
kubectl -n quota-lab describe pod quota-test | grep -A5 Limits

kubectl -n quota-lab describe resourcequota compute-quota \
  > /opt/course/16/quota-status.txt
```

---

## A17 | Helm + Kustomize

```bash
# Part A
helm template nginx-prod bitnami/nginx \
  -n deploy-lab \
  --set replicaCount=3 \
  > /opt/course/17/nginx-helm-template.yaml

kubectl apply -f /opt/course/17/nginx-helm-template.yaml

# Part B - apply prod overlay
kubectl kustomize /opt/course/17/app/prod | kubectl apply -f -
kubectl -n deploy-lab get deploy myapp   # 3/3

# Part B - add image patch
cat >> /opt/course/17/app/prod/kustomization.yaml << 'EOF'
images:
- name: nginx
  newTag: 1.25-alpine
EOF

kubectl kustomize /opt/course/17/app/prod | kubectl apply -f -
kubectl -n deploy-lab get deploy myapp -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should show nginx:1.25-alpine
```

</details>

---

## Topic Coverage (Post-Feb 2025 Curriculum)

| # | Topic | Domain | Weight |
|---|-------|--------|--------|
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

---

*Mock exam 3 prepared for Mohammad Dahamshi — CKA preparation 2026*
*Based on real exam reports from candidates who sat the post-Feb 2025 updated CKA*
