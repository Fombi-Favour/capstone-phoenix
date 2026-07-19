# Cost — TaskApp Kubernetes Cluster (eu-west-2)

## Monthly itemized cost

| Item | Spec | Qty | $/mo |
|---|---|---:|---:|
| Control-plane VM | t3.small (2 vCPU, 2GB RAM) | 1 | ~$15.18 |
| Worker VMs | t3.small (2 vCPU, 2GB RAM) | 2 | ~$30.36 |
| Elastic IP | Static public IP on control-plane | 1 | ~$3.60 |
| EBS root volumes | gp3 20GB per node | 3 | ~$4.80 |
| EBS PVC (Postgres) | gp3 5GB (local-path StorageClass) | 1 | ~$0.40 |
| S3 remote state | Standard storage (<1MB) | 1 | ~$0.02 |
| DynamoDB lock table | On-demand, near-zero writes | 1 | ~$0.01 |
| Data transfer | ~10GB outbound/month estimated | — | ~$0.90 |
| **Total** | | | **~$55.27** |

> Prices based on AWS eu-west-2 (London) on-demand rates as of mid-2026.
> No domain cost — nip.io is free and requires no registration.
> No load balancer cost — ingress-nginx uses hostNetwork on the nodes directly.

---

## Compared to the single-server Compose + Portainer deploy

- **Single-server stack cost:** ~$15–18/month (one t3.small or t3.medium + EBS volume)
- **This cluster costs:** ~$55/month
- **Delta:** ~$37–40/month more

### What the extra spend buys

The single-server Compose setup is a single point of failure — if the instance crashes,
restarts, or gets OOMKilled, the app is down until someone SSHes in. Every deploy causes
a brief outage because containers are stopped before new ones start. There is no
auto-recovery, no traffic distribution, and no way to handle load spikes.

The Kubernetes cluster buys four concrete things the brief asks for:

1. **High availability** — 2 replicas per tier spread across 2 AZs; a worker node can
   die and the app stays up automatically without any human intervention.
2. **Zero-downtime deploys** — `RollingUpdate` with `maxUnavailable: 0` means new pods
   pass readiness probes before old ones terminate. Proven with the unbroken-200s log.
3. **Autoscaling** — HPA scales the backend from 2 to 6 replicas under load and back
   down when traffic drops, without manual intervention.
4. **Self-healing** — liveness probes detect and restart crashed pods; rescheduling
   moves workloads off failed nodes automatically.

**When is it NOT worth it?** For a small internal tool with < 100 users and no SLA,
the operational overhead of Kubernetes (kubeconfig management, upgrade cadence, node
patching, certificate rotation, GitOps pipeline) outweighs the HA benefits. A single
well-monitored server with automated backups and a fast restore runbook is often the
better choice. The cluster makes sense when you have real traffic, a real SLA, or a
team large enough that deploy coordination becomes a problem.

---

## How I'd halve this

The biggest saving is replacing on-demand worker instances with **Spot Instances**.
AWS Spot for t3.small in eu-west-2 runs ~70% cheaper (~$4.50/month each vs $15.18),
dropping the two-worker cost from $30 to ~$9. With a PodDisruptionBudget and two
workers across two AZs, a single Spot interruption reschedules pods to the surviving
worker within 60 seconds — acceptable for a capstone or staging environment. Combined
with dropping the Elastic IP (use a dynamic IP + update the nip.io domain on restart
via a boot script) and shrinking the PVC to 2GB, the total monthly bill falls to
roughly **$22–25/month** — less than half the current cost. For a real production
cluster the control-plane would stay on-demand for stability, with only workers on Spot.
