# Azure Cost Scheduler

Automated start/stop scheduling for AKS clusters to reduce Azure spend on non-production infrastructure, with a manual control workflow gated by approval for on-demand use — including production, treated with the same caution.

---

## What it does

- **Scheduled nightly shutdown** — automatically stops a defined list of non-production AKS clusters every night via cron, with no manual intervention required
- **Manual control** — start or stop any registered cluster on demand, useful before/after a demo or interview, gated behind a GitHub Environment approval step
- A single reusable shell script (`manage-cluster.sh`) backs both workflows, idempotent by design (safe to run against a cluster that's already in the target state)

---

## Why this exists

AKS node VMs are billed by the hour regardless of whether anything is actively using them. Across the projects in this portfolio, clusters were being started and stopped by hand, repeatedly, throughout development — a manual, easy-to-forget, easy-to-get-wrong habit. This project turns that into automated, auditable infrastructure.

---

## Architecture

Scheduled (cron, daily)                    Manual (on demand)

│                                          │

▼                                          ▼

GitHub Actions: scheduled-shutdown.yml    GitHub Actions: manual-control.yml

│                                          │

▼                                          ▼

Stops every cluster in              Gated by GitHub Environment

the CLUSTERS list                   approval (production)

│                                          │

└──────────────────┬───────────────────────┘

                   ▼

scripts/manage-cluster.sh

│

▼

az aks start/stop/show

---

## Safety design

**The scheduled shutdown only ever targets clusters explicitly listed** in the workflow's `CLUSTERS` environment variable — there is no "stop everything" wildcard. Production infrastructure is never included in this list, structurally, not just by convention; adding a cluster to the automatic schedule is a deliberate, visible, one-line code change.

**Every manual action is gated by approval, including starting a cluster.** GitHub Environments gate per-*job*, not per-input-value — there's no native way to say "only require approval if the selected cluster is production." Rather than build brittle conditional-approval logic to avoid gating non-production actions, this project treats the entire manual-control workflow with production-level caution: any manual start or stop, of any cluster, requires a human to click approve. The trade-off is a small amount of friction for routine non-production actions, in exchange for there being exactly one access pattern to reason about and audit.

**Idempotent by design.** Both `start` and `stop` actions check the cluster's current power state before acting, and skip cleanly if it's already in the target state. A scheduled job should never fail just because a cluster was already stopped manually earlier that day.

---

## Project structure

```
azure-cost-scheduler/

├── scripts/

│   └── manage-cluster.sh           # start | stop | status, idempotent

└── .github/

└── workflows/

├── scheduled-shutdown.yml  # cron: nightly stop, non-prod only

└── manual-control.yml      # workflow_dispatch: start/stop any cluster, approval-gated

```

---

## Usage

**Check status of any cluster locally:**
```bash
./scripts/manage-cluster.sh status pl-stats-rg plstats-aks
```

**Manual control via GitHub Actions:**
1. Go to **Actions** → **Manual Cluster Control** → **Run workflow**
2. Choose `start` or `stop` and the target cluster
3. Approve the deployment when prompted

**Scheduled shutdown** runs automatically — no action needed. To add a cluster to the nightly schedule, add it to the `CLUSTERS` variable in `scheduled-shutdown.yml`.

---

## Setup

Requires a subscription-scoped Azure service principal with `Contributor` access (this project reuses the one created for [multi-env-infrastructure](#), which also has the `User Access Administrator` role needed for role assignments elsewhere in this portfolio):

```bash
az role assignment create \
  --assignee "<service-principal-app-id>" \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>
```

Add the credential JSON as a repository secret named `AZURE_CREDENTIALS`, and create a `production` GitHub Environment with required reviewers configured.

---

## Lessons learned / honest notes

**This project was built and validated against four clusters across two other repos in this portfolio** — `plstats-aks`, plus `plinfra-dev-aks`, `plinfra-staging-aks`, and `plinfra-prod-aks` from a multi-environment infrastructure project. Shortly after building this scheduler, the three `plinfra-*` clusters were intentionally decommissioned via `terraform destroy` to reduce ongoing cost while that project was paused. This scheduler's `CLUSTERS` list and the manual-control workflow's cluster options both had to be updated to remove references to infrastructure that no longer existed — a small, concrete example of why platform tooling that manages *other* projects' infrastructure needs to be tracked and updated as a dependent any time that infrastructure changes, not written once and assumed permanent.

A cost-reporting workflow (summarising running/stopped state and approximate spend across all managed clusters) was considered as a third workflow but intentionally deferred — with only one cluster currently under management, the reporting value is minimal right now. It remains a natural extension once multi-environment infrastructure is rebuilt.

---

## Tech stack

| Layer | Technology |
|---|---|
| Scheduling | GitHub Actions `schedule` (cron) |
| On-demand control | GitHub Actions `workflow_dispatch` |
| Approval gating | GitHub Environments with required reviewers |
| Cluster control | Azure CLI (`az aks start` / `stop` / `show`) |