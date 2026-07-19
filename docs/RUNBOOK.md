# RUNBOOK — TaskApp on Kubernetes (Capstone Phoenix)

## Prerequisites

```bash
# Tools needed on your laptop
terraform --version   # >= 1.6
ansible --version     # >= 2.15
kubectl version       # >= 1.30
helm version          # >= 4.2
aws --version         # >= 2.35.9
jq --version          # any

# AWS credentials
aws configure
aws sts get-caller-identity   # must return your account ID
```

---

## Provision from zero

### Step 1 — Bootstrap remote state (run once ever)

```bash
cd infra/terraform
bash bootstrap-state.sh
# Note the bucket name printed — add it to backend.hcl
```

### Step 2 — Configure variables

```bash
cp backend.hcl.example backend.hcl
# Edit: bucket, key, region, dynamodb_table

cp terraform.tfvars.example terraform.tfvars
# Edit: admin_cidr = "$(curl -s https://checkip.amazonaws.com)/32"
#       key_pair_name = "taskapp-capstone"
```

### Step 3 — Create EC2 key pair (if not already done)

```bash
aws ec2 create-key-pair \
  --key-name taskapp-capstone \
  --region eu-west-2 \
  --query "KeyMaterial" \
  --output text > ~/.ssh/taskapp-capstone.pem

chmod 400 ~/.ssh/taskapp-capstone.pem
ssh-keygen -y -f ~/.ssh/taskapp-capstone.pem > ~/.ssh/taskapp-capstone.pem.pub
```

### Step 4 — Provision nodes

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply   # takes ~2 min, type 'yes'

# Verify
terraform output control_plane_public_ip
terraform output worker_public_ips
```

### Step 5 — Cluster bring-up (Ansible)

```bash
cd ../ansible

# Generate inventory from Terraform
cd ../terraform
terraform output -raw ansible_inventory_hint > ../ansible/inventory/hosts.ini
cd ../ansible

# Install Galaxy collections
ansible-galaxy collection install -r requirements.yml

# Verify SSH connectivity
ansible k3s_cluster -m ping   # all nodes must return pong

# Run full playbook
ansible-playbook site.yml

# Verify cluster
kubectl get nodes -o wide
# All 3 nodes must show Ready
```

### Step 6 — Platform (cert-manager, ingress-nginx, Argo CD)

```bash
# cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
kubectl wait --for=condition=available --timeout=120s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-webhook -n cert-manager

# ingress-nginx (hostNetwork — no cloud LB needed)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --set controller.service.enabled=false \
  --set controller.kind=DaemonSet \
  --set controller.admissionWebhooks.enabled=false \
  --timeout 5m --wait

# Verify ingress is alive — use the control-plane public IP
curl -I http://18.169.122.172   # must return 404 from nginx

# Delete leftover webhook if it exists from a failed previous install
kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true

# ClusterIssuer for Let's Encrypt — edit your real email first
kubectl apply -f manifests/platform/cluster-issuer.yaml

# Argo CD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get Argo CD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080 on the browser
```

### Step 7 — Deploy the application

```bash
# Apply namespace, configmap, secret
kubectl apply -f manifests/namespace/

# Apply postgres
kubectl apply -f manifests/postgres/
kubectl wait --for=condition=ready pod/postgres-0 -n taskapp --timeout=120s

# Initialise database tables (first deploy only)
kubectl exec -it postgres-0 -n taskapp -- psql -U taskapp -d taskapp -c "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(80) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL DEFAULT '',
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT DEFAULT '',
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    status VARCHAR(20) NOT NULL DEFAULT 'todo',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);"

# Seed default users
kubectl exec -it \
  $(kubectl get pod -l app=backend -n taskapp -o name | head -1) \
  -n taskapp -- python3 -c \
  "from werkzeug.security import generate_password_hash; print(generate_password_hash('admin123'))" \
  | xargs -I{} kubectl exec -it postgres-0 -n taskapp -- psql -U taskapp -d taskapp -c \
  "INSERT INTO users (username, password_hash) VALUES ('admin', '{}') ON CONFLICT DO NOTHING;"

# Apply backend, frontend, ingress
kubectl apply -f manifests/backend/
kubectl apply -f manifests/frontend/
kubectl apply -f manifests/ingress/

# Apply network policy
kubectl apply -f manifests/network-policy/

# Wait for TLS certificate
kubectl get certificate -n taskapp -w
# Wait for READY = True (1-2 minutes)
```

### Step 8 — GitOps (Argo CD takes over)

```bash
# Edit gitops/taskapp-application.yaml — set your GitHub repo URL
kubectl apply -f gitops/taskapp-application.yaml --validate=false

# Verify sync
kubectl get applications -n argocd
# STATUS must show: Synced / Healthy
```

### Step 9 — Verify the live app

```bash
# Health check
curl -s https://taskapp.18.169.122.172.nip.io/api/health

# Login
TOKEN=$(curl -s -X POST https://taskapp.18.169.122.172.nip.io/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | jq -r '.token')
echo $TOKEN   # must be a JWT string

# Create a task
curl -s -X POST https://taskapp.18.169.122.172.nip.io/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Hello from K8s","priority":"high","status":"todo"}' | jq .

# Open in browser
echo "https://taskapp.18.169.122.172.nip.io"
```

---

## After every PC restart (IPs change)

```bash
# Get new control-plane IP
cd infra/terraform
terraform output control_plane_public_ip

# Update inventory and kubeconfig
terraform output -raw ansible_inventory_hint > ../ansible/inventory/hosts.ini
cd ../ansible
ansible-playbook site.yml   # re-fetches kubeconfig with new IP

kubectl get nodes
```

---

## Day-2 Operations

### Scale a tier

```bash
# GitOps way (Argo auto-syncs within 3 min)
# Edit manifests/backend/backend.yaml → replicas: 3
git add manifests/backend/backend.yaml
git commit -m "scale: backend replicas 2 → 3"
git push

# Emergency override (Argo will revert on next sync)
kubectl scale deployment/backend -n taskapp --replicas=3
```

### Roll back a bad deploy

```bash
# GitOps way
git revert HEAD
git push
# Argo CD detects and syncs the previous state

# Emergency kubectl rollback
kubectl rollout undo deployment/backend -n taskapp
kubectl rollout status deployment/backend -n taskapp
# Then fix the git repo to match immediately
```

### Run a new migration safely

```bash
# Apply the updated migration Job manifest
kubectl apply -f manifests/backend/migration-job.yaml
kubectl wait --for=condition=complete job/taskapp-migrate -n taskapp --timeout=120s
kubectl logs -n taskapp job/taskapp-migrate

# Then roll out the new backend image
kubectl rollout restart deployment/backend -n taskapp
kubectl rollout status deployment/backend -n taskapp
```

### Rotate a secret

```bash
# Re-create the secret with new values
kubectl create secret generic backend-secret \
  --namespace taskapp \
  --from-literal=DATABASE_PASSWORD=<NEW_PASSWORD> \
  --from-literal=DATABASE_URL="postgresql://taskapp:<NEW_PASSWORD>@postgres-service:5432/taskapp" \
  --from-literal=SECRET_KEY=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up new secret
kubectl rollout restart deployment/backend -n taskapp
kubectl rollout status deployment/backend -n taskapp
```

---

## Failure Recovery

### A worker node dies or is drained (live demo)

```bash
# Terminal 1 — watch traffic (must stay 200 throughout)
while true; do
  echo "$(date +%H:%M:%S) $(curl -s -o /dev/null -w '%{http_code}' \
    https://taskapp.18.169.122.172.nip.io/api/health)"
  sleep 1
done

# Terminal 2 — drain the worker
kubectl get nodes
kubectl drain <WORKER_NODE_NAME> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=30

# Terminal 3 — watch pods reschedule
kubectl get pods -n taskapp -o wide -w

# What happens:
# - Kubernetes marks node SchedulingDisabled
# - PDB ensures minAvailable=1 pods stay live during drain
# - Pods reschedule to surviving worker (~30-60s)
# - Traffic stays 200 throughout (topologySpreadConstraints + rolling strategy)

# Bring node back after demo
kubectl uncordon <WORKER_NODE_NAME>
```

### A backend Pod crashloops

```bash
# Identify problem pod
kubectl get pods -n taskapp   # look for CrashLoopBackOff

# Read current logs
kubectl logs -n taskapp <POD_NAME>

# Read logs from the previous crashed container
kubectl logs -n taskapp <POD_NAME> --previous

# Inspect events
kubectl describe pod -n taskapp <POD_NAME>
# Check Events section at the bottom

# Common causes:
# OOMKilled      → increase resources.limits.memory, git push
# Wrong SECRET   → rotate secret (see above), rollout restart
# Bad image tag  → git revert, git push

# Force restart after fix
kubectl rollout restart deployment/backend -n taskapp
kubectl rollout status deployment/backend -n taskapp
```

### A bad migration

```bash
# Stop traffic to backend
kubectl scale deployment/backend -n taskapp --replicas=0

# Connect to postgres
kubectl exec -it postgres-0 -n taskapp -- psql -U taskapp -d taskapp

# Check current schema version
SELECT version_num FROM alembic_version;

# Rollback manually or via one-off pod
kubectl run alembic-rollback \
  --image=ghcr.io/ts-a-devops/taskapp-backend:c2b906d \
  --restart=Never --namespace=taskapp \
  --env-from=secret/backend-secret \
  --env-from=configmap/taskapp-config \
  -- python -m flask db downgrade

kubectl logs -n taskapp alembic-rollback --follow
kubectl delete pod alembic-rollback -n taskapp

# Fix migration, push corrected image, git push
# Scale backend back up
kubectl scale deployment/backend -n taskapp --replicas=2
```

### Postgres Pod is rescheduled — prove data survives

```bash
# Step 1 — write a test record
TOKEN=$(curl -s -X POST https://taskapp.18.169.122.172.nip.io/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | jq -r '.token')

curl -s -X POST https://taskapp.18.169.122.172.nip.io/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"PVC survival test","priority":"medium","status":"todo"}' \
  | tee docs/EVIDENCE/pvc-persist.log

# Step 2 — delete the pod (StatefulSet recreates it immediately)
kubectl delete pod postgres-0 -n taskapp

# Step 3 — watch restart (~20-40s)
kubectl get pods -n taskapp -w
# postgres-0: Terminating → Pending → Running

# Step 4 — verify data survived
curl -s https://taskapp.18.169.122.172.nip.io/api/tasks \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.[] | select(.title=="PVC survival test")'
# Must return the record — PVC survived the pod kill
```

---

## Useful one-liners

```bash
# All pods
kubectl get pods -n taskapp -o wide

# HPA status
kubectl get hpa -n taskapp

# PDB status
kubectl get pdb -n taskapp

# Certificate status
kubectl get certificate -n taskapp

# Argo CD sync status
kubectl get applications -n argocd

# Resource usage
kubectl top pods -n taskapp
kubectl top nodes

# Tail backend logs
kubectl logs -n taskapp -l app=backend --follow --max-log-requests=10

# Shell into backend
kubectl exec -it -n taskapp deployment/backend -- /bin/sh

# Shell into postgres
kubectl exec -it postgres-0 -n taskapp -- psql -U taskapp -d taskapp

# Force Argo CD immediate sync
kubectl annotate application taskapp -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```
