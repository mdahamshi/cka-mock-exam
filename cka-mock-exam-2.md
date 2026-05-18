# CKA Mock Exam 2 — Mohammad Dahamshi
## Kubernetes 1.35 | 17 Questions | 120 Minutes
### Cluster: cp (control-plane), node01, node02

---

> **Before you start:**
> ```bash
> source ~/.bashrc   # loads: alias k=kubectl, $do, $now, completion
> ```
> Return to your main terminal with `exit` before switching nodes.
> **Passing score: 66%**

---

## Question 1 | DNS / FQDN / Headless Service (6%)
**Node: `cp`**

The Deployment `controller` in Namespace `lima-control` communicates with cluster-internal
endpoints via DNS FQDNs stored in ConfigMap `control-config`.

Update the ConfigMap with the **correct FQDN values** for:

| Key | Target |
|-----|--------|
| `DNS_1` | Service `kubernetes` in Namespace `default` |
| `DNS_2` | Headless Service `department` in Namespace `lima-workload` |
| `DNS_3` | Pod `section100` in Namespace `lima-workload` — must work even if the Pod IP changes |
| `DNS_4` | A Pod with IP `1.2.3.4` in Namespace `kube-system` |

After updating, rollout restart the `controller` Deployment and confirm the logs show
successful `nslookup` resolution for all four entries.

> **Hint:** Exec into a `controller` Pod and test with `nslookup` before editing the ConfigMap.
> For DNS_3 check how the Pod's `hostname` and `subdomain` fields work with the `section` Service.

---

## Question 2 | Static Pod + NodePort Service (4%)
**Node: `cp`**

1. Create a **Static Pod** named `my-static-pod` in Namespace `default` on the control-plane node:
   - Image: `nginx:1-alpine`
   - Resource requests: `10m` CPU, `20Mi` memory
   - Place the manifest in `/etc/kubernetes/manifests/`

2. Create a **NodePort Service** named `static-pod-service` that exposes the static Pod on **port 80**.

3. Verify:
   - The service has **one Endpoint**
   - You can `curl <node-internal-IP>:<NodePort>` and get an nginx response

---

## Question 3 | Kubelet Client/Server Certificate Info (4%)
**Node: `cp` → `ssh node01`**

On `node01`, find:

- The **Kubelet Client Certificate** (used for outgoing connections to the kube-apiserver)
- The **Kubelet Server Certificate** (used for incoming connections from the kube-apiserver)

For each certificate, extract and record:
- `Issuer`
- `Extended Key Usage`

Write the findings into `/opt/course/3/certificate-info.txt` on `cp`.

> **Hint:** Look in `/var/lib/kubelet/pki/` on node01.
> Use `openssl x509 -noout -text -in <file> | grep -E "Issuer|Extended Key Usage" -A1`

---

## Question 4 | Pod Ready Only if Service is Reachable (5%)
**Node: `cp`**

In Namespace `default`:

1. Create a Pod named `ready-if-service-ready` with image `nginx:1-alpine`:
   - **LivenessProbe**: exec `true`
   - **ReadinessProbe**: exec `wget -T2 -O- http://service-am-i-ready:80`

2. Confirm the Pod starts but is **not Ready** (the service has no endpoints yet).

3. Create a second Pod named `am-i-ready` with image `nginx:1-alpine` and label `id=cross-server-ready`.

4. Confirm the Service `service-am-i-ready` now has `am-i-ready` as an endpoint,
   and that `ready-if-service-ready` transitions to **Ready**.

---

## Question 5 | kubectl Sorting Scripts (3%)
**Node: `cp`**

1. Write a command into `/opt/course/5/find_pods.sh` that lists all Pods in all Namespaces,
   **sorted by AGE** (`metadata.creationTimestamp`).

2. Write a command into `/opt/course/5/find_pods_uid.sh` that lists all Pods in all Namespaces,
   **sorted by `metadata.uid`**.

Verify both scripts are executable and produce correctly sorted output.

---

## Question 6 | Fix Broken Kubelet (6%)
**Node: `node01`**

The kubelet on `node01` is not running. It was broken intentionally:
the kubelet binary path in the systemd drop-in config is wrong.

1. SSH into `node01` and investigate why the kubelet fails to start.
2. Fix the kubelet binary path in `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf`.
3. Reload systemd, restart the kubelet, and confirm `node01` shows `Ready`.
4. Back on `cp`, create a Pod named `success` (image `nginx:1-alpine`) in `default` namespace
   and confirm it's running.

> **Hint:** Check `service kubelet status`, then try running the binary path directly to see
> the actual error. Compare with `whereis kubelet`.

---

## Question 7 | etcd Operations (5%)
**Node: `cp`**

1. Get the **etcd version** by running `etcd --version` inside the etcd Pod and save the output
   to `/opt/course/7/etcd-version`.

2. Create an **etcd snapshot** and save it to `/opt/course/7/etcd-snapshot.db`.
   Use the correct certificates (check `/etc/kubernetes/manifests/etcd.yaml`).

3. Verify the snapshot with:
   ```bash
   ETCDCTL_API=3 etcdctl snapshot status /opt/course/7/etcd-snapshot.db --write-out=table
   ```

> **Hint:** etcd is not installed directly on the node — it runs as a Pod.
> Use `kubectl -n kube-system exec etcd-<name> -- etcd --version` for step 1.

---

## Question 8 | Identify Controlplane Component Types (5%)
**Node: `cp`**

Investigate how each controlplane component is started/managed. Write your findings into
`/opt/course/8/controlplane-components.txt` using this format:

```
kubelet: [TYPE]
kube-apiserver: [TYPE]
kube-scheduler: [TYPE]
kube-controller-manager: [TYPE]
etcd: [TYPE]
dns: [TYPE] [NAME]
```

Valid types: `not-installed`, `process`, `static-pod`, `pod`

> **Hint:** Check `systemd`, `/etc/kubernetes/manifests/`, and `kubectl -n kube-system get pod,deploy,ds`.

---

## Question 9 | Stop Scheduler — Manual Pod Scheduling (6%)
**Node: `cp`**

1. **Temporarily stop** the `kube-scheduler` (in a way it can be restarted).

2. Create a Pod named `manual-schedule` with image `httpd:2-alpine`.
   Confirm it remains in `Pending` state (no node assigned).

3. **Manually schedule** the Pod onto the `cp` node by setting `spec.nodeName` directly,
   then replacing the Pod. Confirm it's `Running` on `cp`.

4. **Restart** the kube-scheduler.

5. Create a second Pod named `manual-schedule2` with image `httpd:2-alpine`.
   Confirm the scheduler places it on `node01` automatically.

---

## Question 10 | Dynamic PV Provisioning + Job (6%)
**Node: `cp`**

**All work** should be in namespace `project-bern`.

1. Create a **StorageClass** named `local-backup`:
   - Provisioner: `rancher.io/local-path`
   - `volumeBindingMode: WaitForFirstConsumer`
   - `reclaimPolicy: Retain` (keep PV even after PVC is deleted)

2. Adjust the Job at `/opt/course/10/backup.yaml`:
   - Replace the `emptyDir` volume with a **PVC** named `backup-pvc`
   - PVC should request `50Mi` and use the `local-backup` StorageClass
   - Add the PVC definition to the same file (separated by `---`)

3. Deploy: delete any existing Job and apply the updated file.

4. Verify:
   - Job completed successfully (1/1)
   - PVC is `Bound`
   - A PV was dynamically created with `Retain` policy

> **Hint:** Use `kubectl get job,pod,pvc,pv -n project-bern` to verify everything.

---

## Question 11 | Secrets — Volume Mount + Env Variables (5%)
**Node: `cp`**

In Namespace `secret`:

1. Create the Secret from `/opt/course/11/secret1.yaml`
   (update its Namespace to `secret` first).

2. Create a new Secret named `secret2` with:
   - `user=user1`
   - `pass=1234`

3. Create a Pod named `secret-pod` with image `busybox:1` running `sleep 1d`:
   - Mount `secret1` **read-only** at `/tmp/secret1`
   - Expose `secret2`'s `user` key as env var `APP_USER`
   - Expose `secret2`'s `pass` key as env var `APP_PASS`

4. Verify:
   ```bash
   k -n secret exec secret-pod -- env | grep APP
   k -n secret exec secret-pod -- find /tmp/secret1
   ```

---

## Question 12 | Schedule Pod on Controlplane Only (4%)
**Node: `cp`**

Create a Pod named `pod1` in Namespace `default`:

- Image: `httpd:2-alpine`
- Container name: `pod1-container`
- Must be scheduled **only on controlplane nodes**
- Do **not** add any new labels to any node

> **Hint:** The controlplane has a `NoSchedule` taint. You need both a **toleration** and
> a **nodeSelector** (or `nodeAffinity`) pointing to the control-plane role.

---

## Question 13 | Multi-Container Pod with Shared Volume (4%)
**Node: `cp`**

Create a Pod named `multi-container-playground` in Namespace `default` with:

- A shared `emptyDir` volume mounted at `/vol` in all containers
- **Container `c1`** (image `nginx:1-alpine`):
  - Env var `MY_NODE_NAME` set to the node name via the Downward API (`spec.nodeName`)
- **Container `c2`** (image `busybox:1`):
  - Command: `while true; do date >> /vol/date.log; sleep 1; done`
- **Container `c3`** (image `busybox:1`):
  - Command: `tail -f /vol/date.log`

Verify:
```bash
k exec multi-container-playground -c c1 -- env | grep MY_NODE_NAME
k logs multi-container-playground -c c3
```

---

## Question 14 | Cluster Information (4%)
**Node: `cp`**

Find the following information about the cluster and write it into `/opt/course/14/cluster-info`:

```
1: [number of controlplane nodes]
2: [number of worker nodes]
3: [Service CIDR range]
4: [CNI plugin name], [path to its config file]
5: [suffix that static pods have on this node]
```

> **Hints:**
> - Service CIDR: `cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep range`
> - CNI: `ls /etc/cni/net.d/`
> - Static pod suffix: it's the node hostname with a leading `-`

---

## Question 15 | Cluster Event Logging (5%)
**Node: `cp`**

1. Write a `kubectl` command into `/opt/course/15/cluster_events.sh` that shows
   **all cluster events sorted by time** (`metadata.creationTimestamp`).

2. **Delete** the `kube-proxy` Pod and write the resulting events into
   `/opt/course/15/pod_kill.log`.

3. Using `crictl`, **kill the containerd container** of the new kube-proxy Pod directly,
   then write those events into `/opt/course/15/container_kill.log`.

> **Hint:** `crictl ps | grep kube-proxy` to find the container ID,
> then `crictl rm --force <id>`.

---

## Question 16 | Namespaced Resources + Find Most Roles (4%)
**Node: `cp`**

1. Write the names of **all namespaced Kubernetes resources** into `/opt/course/16/resources.txt`.

2. Among all `project-*` Namespaces, find the one with the **highest number of Roles**.
   Write its name and the count into `/opt/course/16/crowded-namespace.txt` like:
   ```
   project-beta with 15 roles
   ```

> **Hint:** `kubectl api-resources --namespaced -o name`
> Then: `kubectl -n project-<name> get role --no-headers | wc -l` for each namespace.

---

## Question 17 | Kustomize + CRDs + RBAC Fix (8%)
**Node: `cp`**

There is a Kustomize config at `/opt/course/17/operator/`. It installs an operator that
works with two CRDs: `students` and `classes`.

It was already deployed with:
```bash
kubectl kustomize /opt/course/17/operator/prod | kubectl apply -f -
```

**Tasks:**

1. Check the **operator Pod logs** — it fails because the `operator-role` is missing
   permissions. Find which resources need to be listed and fix `base/rbac.yaml`
   to grant `list` on both `students` and `classes` in the `education.local` API group.

2. Add a **new Student resource** named `student4` with any name and description
   to `base/students.yaml`.

3. Re-deploy the prod overlay:
   ```bash
   kubectl kustomize /opt/course/17/operator/prod | kubectl apply -f -
   ```

4. Verify the operator logs no longer show permission errors, and that `student4` appears:
   ```bash
   k -n operator-prod get student
   k -n operator-prod logs deploy/operator
   ```

---

# Answer Key

<details>
<summary>Click to expand — try it yourself first!</summary>

## A1 | DNS FQDNs

| Key | FQDN |
|-----|------|
| DNS_1 | `kubernetes.default.svc.cluster.local` |
| DNS_2 | `department.lima-workload.svc.cluster.local` |
| DNS_3 | `section100.section.lima-workload.svc.cluster.local` |
| DNS_4 | `1-2-3-4.kube-system.pod.cluster.local` |

```bash
# Exec into controller pod to test first
k -n lima-control exec -it deploy/controller -- sh
/ # nslookup kubernetes.default.svc.cluster.local
/ # nslookup department.lima-workload.svc.cluster.local
/ # nslookup section100.section.lima-workload.svc.cluster.local
/ # nslookup 1-2-3-4.kube-system.pod.cluster.local
exit

# Update ConfigMap
k -n lima-control edit cm control-config

# Restart deployment
k -n lima-control rollout restart deploy controller
k -n lima-control rollout status deploy controller
k -n lima-control logs -f deploy/controller
```

---

## A2 | Static Pod + NodePort

```bash
sudo -i
cd /etc/kubernetes/manifests/

k run my-static-pod --image=nginx:1-alpine --dry-run=client -o yaml > my-static-pod.yaml
# edit to add resource requests under containers[0]:
#   resources:
#     requests:
#       cpu: 10m
#       memory: 20Mi

# Wait for it to appear
k get pod -A | grep my-static

# Expose it
k expose pod my-static-pod-cp --name static-pod-service --type=NodePort --port 80

# Verify endpoint and curl
k get svc,endpointslice -l run=my-static-pod
NODE_IP=$(k get node cp -o jsonpath='{.status.addresses[0].address}')
NODE_PORT=$(k get svc static-pod-service -o jsonpath='{.spec.ports[0].nodePort}')
curl $NODE_IP:$NODE_PORT
```

---

## A3 | Kubelet Cert Info

```bash
ssh node01
sudo -i

# Client certificate (outgoing to apiserver)
openssl x509 -noout -text -in /var/lib/kubelet/pki/kubelet-client-current.pem \
  | grep -E "Issuer|Extended Key Usage" -A1

# Server certificate (incoming from apiserver)
openssl x509 -noout -text -in /var/lib/kubelet/pki/kubelet.crt \
  | grep -E "Issuer|Extended Key Usage" -A1
exit

# Write to file on cp
cat > /opt/course/3/certificate-info.txt <<'EOF'
Kubelet Client Certificate:
Issuer: CN = kubernetes
Extended Key Usage: TLS Web Client Authentication

Kubelet Server Certificate:
Issuer: CN = node01-ca@<timestamp>
Extended Key Usage: TLS Web Server Authentication
EOF
```

---

## A4 | ReadinessProbe cross-pod

```yaml
# ready-if-service-ready pod
apiVersion: v1
kind: Pod
metadata:
  name: ready-if-service-ready
spec:
  containers:
  - name: ready-if-service-ready
    image: nginx:1-alpine
    livenessProbe:
      exec:
        command: ["true"]
    readinessProbe:
      exec:
        command:
        - sh
        - -c
        - wget -T2 -O- http://service-am-i-ready:80
```
```bash
k apply -f pod1.yaml
k get pod ready-if-service-ready   # should be 0/1 Running

# Create second pod
k run am-i-ready --image=nginx:1-alpine --labels="id=cross-server-ready"

# Wait ~30s then check
k get pod ready-if-service-ready   # should be 1/1 Running
```

---

## A5 | kubectl sorting

```bash
# /opt/course/5/find_pods.sh
echo 'kubectl get pod -A --sort-by=.metadata.creationTimestamp' > /opt/course/5/find_pods.sh

# /opt/course/5/find_pods_uid.sh
echo 'kubectl get pod -A --sort-by=.metadata.uid' > /opt/course/5/find_pods_uid.sh

chmod +x /opt/course/5/find_pods.sh /opt/course/5/find_pods_uid.sh
sh /opt/course/5/find_pods.sh
sh /opt/course/5/find_pods_uid.sh
```

---

## A6 | Fix Kubelet

```bash
ssh node01
sudo -i

service kubelet status          # inactive or failing
/usr/local/bin/kubelet          # No such file or directory -> wrong path
whereis kubelet                 # shows /usr/bin/kubelet

vim /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Change last ExecStart line:
# ExecStart=/usr/local/bin/kubelet ...
# to:
# ExecStart=/usr/bin/kubelet ...

systemctl daemon-reload
service kubelet restart
service kubelet status          # active (running)
exit

k get node                      # node01 should be Ready
k run success --image=nginx:1-alpine
k get pod success
```

---

## A7 | etcd Operations

```bash
sudo -i

# Step 1 - etcd version via Pod exec
ETCD_POD=$(k -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
k -n kube-system exec $ETCD_POD -- etcd --version > /opt/course/7/etcd-version

# Step 2 - snapshot
ETCDCTL_API=3 etcdctl snapshot save /opt/course/7/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Step 3 - verify
ETCDCTL_API=3 etcdctl snapshot status /opt/course/7/etcd-snapshot.db --write-out=table
```

---

## A8 | Controlplane Component Types

```bash
sudo -i
find /usr/lib/systemd | grep kube     # kubelet -> process
ls /etc/kubernetes/manifests/         # kube-apiserver, kube-scheduler, kube-controller-manager, etcd -> static-pod
k -n kube-system get deploy           # coredns -> pod (deployment)

cat > /opt/course/8/controlplane-components.txt <<'EOF'
kubelet: process
kube-apiserver: static-pod
kube-scheduler: static-pod
kube-controller-manager: static-pod
etcd: static-pod
dns: pod coredns
EOF
```

---

## A9 | Manual Scheduling

```bash
sudo -i

# Stop scheduler
cd /etc/kubernetes/manifests/
mv kube-scheduler.yaml ..
watch crictl ps   # wait until scheduler container is gone

# Create pod and confirm Pending
k run manual-schedule --image=httpd:2-alpine
k get pod manual-schedule -o wide   # NODE = <none>

# Manually schedule
k get pod manual-schedule -o yaml > /tmp/9.yaml
# Add under spec: nodeName: cp
# Then replace
k replace --force -f /tmp/9.yaml
k get pod manual-schedule -o wide   # should run on cp

# Restart scheduler
mv ../kube-scheduler.yaml .
k -n kube-system get pod | grep scheduler

# Test auto scheduling
k run manual-schedule2 --image=httpd:2-alpine
k get pod -o wide | grep schedule   # manual-schedule2 should land on node01
```

---

## A10 | Dynamic PV + Job

```yaml
# Add to /opt/course/10/backup.yaml
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-backup
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
  namespace: project-bern
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Mi
  storageClassName: local-backup
```
Then in the Job spec, replace `emptyDir: {}` with:
```yaml
      volumes:
      - name: backup
        persistentVolumeClaim:
          claimName: backup-pvc
```
```bash
k -n project-bern delete job backup 2>/dev/null || true
k apply -f /opt/course/10/backup.yaml
k -n project-bern get job,pod,pvc,pv
```

---

## A11 | Secrets

```bash
# Secret 1
cp /opt/course/11/secret1.yaml /tmp/secret1.yaml
# Edit: set namespace: secret
k apply -f /tmp/secret1.yaml

# Secret 2
k -n secret create secret generic secret2 \
  --from-literal=user=user1 --from-literal=pass=1234

# Pod
k -n secret run secret-pod --image=busybox:1 --dry-run=client -o yaml \
  -- sh -c "sleep 1d" > /tmp/11.yaml
```
Edit to add env vars and volume mount, then:
```bash
k apply -f /tmp/11.yaml
k -n secret exec secret-pod -- env | grep APP
k -n secret exec secret-pod -- find /tmp/secret1
```

---

## A12 | Schedule on Controlplane

```bash
k get node cp --show-labels | grep control-plane
k describe node cp | grep Taint   # node-role.kubernetes.io/control-plane:NoSchedule

k run pod1 --image=httpd:2-alpine --dry-run=client -o yaml > /tmp/12.yaml
```
Add to the Pod spec:
```yaml
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    effect: NoSchedule
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  containers:
  - name: pod1-container   # rename from pod1
    image: httpd:2-alpine
```
```bash
k apply -f /tmp/12.yaml
k get pod pod1 -o wide   # NODE = cp
```

---

## A13 | Multi-container Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-playground
spec:
  volumes:
  - name: vol
    emptyDir: {}
  containers:
  - name: c1
    image: nginx:1-alpine
    env:
    - name: MY_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    volumeMounts:
    - name: vol
      mountPath: /vol
  - name: c2
    image: busybox:1
    command: ["sh", "-c", "while true; do date >> /vol/date.log; sleep 1; done"]
    volumeMounts:
    - name: vol
      mountPath: /vol
  - name: c3
    image: busybox:1
    command: ["sh", "-c", "tail -f /vol/date.log"]
    volumeMounts:
    - name: vol
      mountPath: /vol
```

---

## A14 | Cluster Info

```bash
sudo -i
k get node                                        # count cp and workers
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep range   # service CIDR
ls /etc/cni/net.d/                                # CNI config file
cat /etc/cni/net.d/<file> | grep type            # CNI plugin name
hostname                                          # static pod suffix = -<hostname>

cat > /opt/course/14/cluster-info <<EOF
1: 1
2: 1
3: 10.96.0.0/12
4: weave, /etc/cni/net.d/10-weave.conflist
5: -cp
EOF
```

---

## A15 | Event Logging

```bash
# Step 1
echo 'kubectl get events -A --sort-by=.metadata.creationTimestamp' \
  > /opt/course/15/cluster_events.sh
chmod +x /opt/course/15/cluster_events.sh

# Step 2
k -n kube-system delete pod -l k8s-app=kube-proxy
sh /opt/course/15/cluster_events.sh 2>/dev/null | tail -20 \
  > /opt/course/15/pod_kill.log

# Step 3
sudo crictl ps | grep kube-proxy
sudo crictl rm --force <container-id>
sh /opt/course/15/cluster_events.sh 2>/dev/null | tail -10 \
  > /opt/course/15/container_kill.log
```

---

## A16 | Namespaced Resources + Roles

```bash
# Part 1
kubectl api-resources --namespaced -o name > /opt/course/16/resources.txt

# Part 2 - check all project-* namespaces
for ns in $(k get ns --no-headers | awk '{print $1}' | grep project-); do
  count=$(k -n $ns get role --no-headers 2>/dev/null | wc -l)
  echo "$ns: $count"
done

# Write the highest
echo "project-beta with 15 roles" > /opt/course/16/crowded-namespace.txt
```

---

## A17 | Kustomize + CRD RBAC Fix

```bash
# Check logs
k -n operator-prod logs deploy/operator
# See: cannot list resource "students" / "classes"

# Fix base/rbac.yaml - update the Role rules section:
vim /opt/course/17/operator/base/rbac.yaml
```
Change the `rules` section in the Role to:
```yaml
rules:
- apiGroups: ["education.local"]
  resources: ["students", "classes"]
  verbs: ["list"]
```
```bash
# Add student4 to base/students.yaml
cat >> /opt/course/17/operator/base/students.yaml <<'EOF'
---
apiVersion: education.local/v1
kind: Student
metadata:
  name: student4
spec:
  name: David Chen
  description: Expert in Kubernetes storage and stateful applications
EOF

# Deploy
kubectl kustomize /opt/course/17/operator/prod | kubectl apply -f -

# Verify
k -n operator-prod get student
k -n operator-prod logs deploy/operator   # no more Forbidden errors
```

</details>

---
