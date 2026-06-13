# nginx-container-apps-actions-infra

Infrastructure as Code and CI/CD pipelines for a containerized Nginx static site deployed to Azure Container Apps using Terraform modules and GitHub Actions, featuring revision-based canary deployments, KEDA autoscaling, and policy-driven governance.

---

## Highlights

- GitHub Actions reusable workflows and matrix strategy validation
- OIDC federated authentication — no client secrets stored anywhere
- Terraform modules pattern with remote state per environment
- Azure Container Apps with revision-based canary deployments (20/80 traffic split)
- KEDA HTTP autoscaling (1–3 replicas, concurrency-based)
- ACR Managed Identity authentication — no admin credentials
- Trivy container image scanning → GitHub Security tab
- Checkov IaC scanning + TFLint with Azure ruleset
- Application Insights, Log Analytics, availability tests, and SRE Workbook
- Azure Policy assignments for tag enforcement, HTTPS-only, and Managed Identity requirements
- PR validation workflow as a merge gate on `main`

---

## Repository Structure

```
nginx-container-apps-actions-infra/
├── .github/
│   ├── workflows/
│   │   ├── infrastructure.yml       
│   │   ├── application.yml          
│   │   ├── reusable-terraform.yml   
│   │   └── pr-validation.yml        
│   └── dependabot.yml
├── app/
│   ├── html/
│   │   └── index.html
│   └── Dockerfile
├── infra/
│   ├── main/                        
│   ├── modules/
│   │   ├── container-app/           
│   │   ├── container-registry/      
│   │   ├── key-vault/               
│   │   └── monitoring/              
│   └── env/
│       ├── dev.tfvars
│       └── prod.tfvars
├── scripts/
│   ├── bootstrap.sh
│   ├── assign-azure-roles.ps1
│   └── create-federated-credentials.ps1
└── README.md
```

---

## Infrastructure

Both `dev` and `prod` environments provision identical resources:

| Resource | Name Pattern |
|---|---|
| Resource Group | `rg-main-nginx-aca-{env}` |
| Container Registry | `acrnginxaca{env}` |
| Key Vault | `kv-nginx-aca-{env}` |
| Container Apps Environment | `cae-nginx-aca-{env}` |
| Container App | `ca-nginx-aca-{env}` |
| Log Analytics Workspace | `log-nginx-aca-{env}` |
| Application Insights | `appi-nginx-aca-{env}` |
| Availability Test + Alert | `avail-nginx-aca-{env}` |
| SRE Workbook | `wb-sre-nginx-aca-{env}` |
| Policy Assignments | tag enforcement, HTTPS-only, Managed Identity |

Terraform state is stored separately per environment in Azure Blob Storage (`stnginxaca{env}`).

---

## CI/CD Architecture

### Infrastructure Pipeline

```
Validate (dev) ──┐  parallel matrix
Validate (prod) ─┘
        ↓
Deploy — dev (terraform apply)
        ↓
Deploy — prod (terraform apply)
```

Each job calls `reusable-terraform.yml` via `workflow_call` — Terraform init (runtime backend config injection), validate, TFLint, Checkov → SARIF, plan, apply.

### PR Validation Pipeline

Triggered on pull requests to `main` modifying `infra/**`. Runs `terraform plan`, TFLint, and Checkov across both environments in parallel. Combined with branch protection rules, this enforces infrastructure validation as a merge gate before any change reaches `main`.

### Application Pipeline

```
Build — generate SHA tag, docker build, Trivy scan, push to dev ACR
        ↓
Deploy — dev
  ├── Capture current active revision
  ├── Configure ACR registry
  ├── Deploy new revision
  ├── Query actual revision name from Azure
  ├── Smoke test new revision at 0% traffic
  ├── Shift traffic: 20% new / 80% previous
  ├── Smoke test main FQDN
  └── Promote new revision to 100%
        ↓
Promote — az acr import (server-side copy, dev ACR → prod ACR)
        ↓
Deploy — prod 
  └── (identical canary sequence against prod resources)
```

**Concurrency protection** — a workflow-level `concurrency` group prevents parallel runs from racing on the same Container App's revision traffic.

**Image tagging** — short git SHA (`nginx-aca/web:{sha}`) provides a direct audit trail from any running container back to its source commit. The `latest` tag is pushed alongside for convenience but never used for deployments.

---

## Security

### Identity and Authentication

- OIDC federated credentials scoped to GitHub environments
- System-assigned Managed Identity on the Container App for ACR and Key Vault access
- ACR admin credentials disabled
- Key Vault in RBAC mode

### Security Tooling

| Tool | Purpose |
|---|---|
| Trivy | Container image vulnerability scanning |
| Checkov | Terraform IaC security scanning |
| TFLint | Terraform static analysis with Azure ruleset |
| Azure Policy | Governance enforcement as code |

---

## Monitoring and SRE

- Application Insights with availability tests (2 Azure regions, 5-minute frequency)
- Metric alert firing when availability drops below SLO target
- Diagnostic settings at Container Apps **Environment** scope
- SRE Workbook visualizing availability and request telemetry against the SLO

---

## Key Design Decisions

- **Bootstrap image** – Container Apps requires a pullable image during initial provisioning. A public bootstrap image is used for the first deployment before switching to ACR-managed images.

- **Post-provisioning registry configuration** – ACR authentication is configured by the application pipeline after the Container App and its Managed Identity exist, avoiding a provisioning dependency cycle.

- **Environment-level diagnostics** – Container Apps emit logs at the Container Apps Environment scope rather than per application.

- **Cross-module dependencies** – Availability tests are orchestrated from the root module to avoid circular dependencies between monitoring and application modules.

- **Promotion workflow** – Images are promoted into production ACR before deployment approval. The approval gate protects the production traffic update rather than the image import itself.

---

## Technologies

- **Terraform** — IaC with modules pattern, `random` provider for workbook UUID
- **GitHub Actions** — reusable workflows, matrix strategy, concurrency control
- **Docker** — Nginx Alpine image
- **Azure Container Apps** — serverless containers, Multiple revision mode
- **Azure Container Registry** — Standard SKU, quarantine policy, retention
- **Azure Key Vault** — RBAC mode, purge protection
- **Azure Application Insights + Monitor** — telemetry, alerts, workbooks
- **Azure Policy** — built-in policy assignments as code
- **Checkov** — IaC security scanning
- **Trivy** — container image scanning
- **TFLint** — Terraform linting with Azure ruleset

---