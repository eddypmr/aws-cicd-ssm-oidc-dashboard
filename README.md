# Project 3 — Enterprise CI/CD on AWS with OIDC + SSM (No SSH, No Static Keys)

This project demonstrates an enterprise-style deployment pipeline on AWS:
- **No SSH access**
- **No long-lived AWS access keys**
- Deploys to an EC2 instance using **AWS Systems Manager (SSM)**
- GitHub Actions authenticates to AWS using **OIDC** (temporary credentials via STS)
- The application runs as a Docker container (FastAPI + static frontend)

---

## ✅ What this project includes

### App (FastAPI + Frontend)
A lightweight “Ops Status Dashboard” that exposes:
- `GET /health` → basic health check
- `GET /version` → version/commit placeholders (can be injected by CI)
- `GET /system` → hostname, uptime, OS, python version
- `GET /docker` → optional check (disabled by default for security)

### Infrastructure (Terraform)
Provisioned in **eu-west-1 (Ireland)**:
- VPC + public subnet + Internet Gateway
- Security Group:
  - ✅ HTTP 80 open to the world
  - ❌ SSH 22 closed
- EC2 instance (Amazon Linux 2023) with:
  - Docker + Git installed
  - SSM Agent enabled
  - IAM Role attached: `AmazonSSMManagedInstanceCore`

### CI/CD (GitHub Actions)
On push to `main`:
1. GitHub Actions uses **OIDC** to assume an AWS IAM Role (**no secrets / no access keys**)
2. Sends an **SSM Run Command** to the EC2 instance
3. EC2 pulls the repo, builds the Docker image, and runs the container on port 80

---

## 🧱 Architecture
```
Developer push → GitHub Actions
└─(OIDC)→ AWS STS (temporary creds)
        → IAM Role (trust limited to repo + branch)
        → AWS SSM SendCommand
        → EC2 (no SSH) runs deployment script
        → Docker container serves app on :80
```

---

## 🔐 Why this is “enterprise-style”
- **No SSH**: reduces attack surface
- **No AWS keys stored in GitHub**: avoids long-lived credentials leakage
- Uses **OIDC + STS**: short-lived credentials only
- Uses **SSM** for controlled remote execution (auditable)

---

## 🚀 How to run locally

### Build & run
From repo root:

```bash
docker build -t ops-dashboard:dev -f app/api/Dockerfile app
docker run --rm -p 8080:8000 ops-dashboard:dev
```

OPEN in http://localhost:8080/

## ☁️ Deploy flow (CI/CD)

1- GitHub Actions workflow:

    .github/workflows/deploy.yml

2- SSM deployment actions:

    clone repo into /home/ec2-user/app

    build image: ops-dashboard:latest   

    run container: -p 80:8000

## 🧹 Cleanup / Cost control

``` 
    cd infra
    terraform destroy
```

### NOTAS ###

/docker endpoint is intentionally not available in production by default.
Allowing a container to control Docker requires mounting the Docker socket (/var/run/docker.sock), which is often avoided for security reasons.
