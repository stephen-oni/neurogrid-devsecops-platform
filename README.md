# NeuroGrid: High-Availability Cloud Infrastructure & DevSecOps Platform

An enterprise-grade, multi-tier web application and observability platform deployed on AWS using Terraform (IaC), Docker Compose, Python, and an automated GitHub Actions CI/CD pipeline.

---

## What NeuroGrid Is All About

**NeuroGrid** is a distributed neural compatibility and implant assessment platform engineered with strict zero-trust security, dynamic scaling, and deep telemetry.

* **User Authentication & Anti-Abuse Engine:** Implements Bcrypt password hashing, session-based route protection, IP-restricted rate-limiting (1 account per IP to prevent spam registration), and automatic account lockout after 3 consecutive failed login attempts.
* **Algorithmic Compatibility Engine:** Evaluates multi-variable bio-telemetry submissions (synapse speeds, rejection tolerances, cortex voltages, and nanite counts) against a weighted scoring algorithm to compute implant tiers and compatibility classifications in real time.
* **Real-Time Dynamic Telemetry:** Exposes active system health checks and runtime performance metrics (`/metrics`) using `prometheus-flask-exporter` alongside host hardware metrics from `node_exporter`.

---

## Architecture Overview

![Pulse Architecture Diagram](architecture/photo.png) 

### Key Architectural Highlights

* **Global Content Delivery:** Frontend static assets hosted in a private Amazon S3 bucket fronted by Amazon CloudFront with Origin Access Control (OAC) and automated cache invalidation.
* **Dynamic API Reverse Proxy:** CloudFront dynamically routes `/api/*` traffic directly to an Application Load Balancer (ALB) across multiple public availability zones.
* **Auto-Scaling Compute Tier:** Containerized Flask backend application and Node Exporter running across private subnets via an Auto Scaling Group (ASG) and Launch Template, completely isolated from direct internet access.
* **Managed Multi-AZ Database:** Amazon RDS MySQL 8.0 configured with synchronous multi-AZ standby replication across private database subnets, strictly accessible only from backend compute security groups over port 3306.
* **Dedicated Standalone Observability Host:** Standalone EC2 instance in a public subnet running Prometheus and Grafana in Docker. Ingress ports 3000 and 9090 are completely closed to the internet. It uses AWS EC2 Service Discovery (`ec2_sd_configs`) via an IAM Role to automatically scrape dynamic ASG worker nodes over private VPC IPs.
* **Zero-Trust Management (No Port 22 / SSH):** Inbound SSH is disabled across the entire infrastructure. All instance provisioning, deployment orchestration, and administrative dashboard access execute strictly through AWS Systems Manager (SSM) Session Manager.

---

## End-to-End User Flow & Telemetry Lifecycle

1. **Edge Resolution & Static Delivery:** When a user visits `https://<CLOUDFRONT_DOMAIN>`, AWS Route 53 directs the request to the nearest CloudFront edge location. CloudFront matches the default root pattern (`/*`) and fetches the Single Page Application bundle from the private Amazon S3 bucket via Origin Access Control (OAC). S3 completely denies public read requests; it only authorizes CloudFront's cryptographically signed OAC principal.
2. **Dynamic API Routing & SSL Termination:** When the user signs up, logs in, or submits neural bio-telemetry, the client executes an asynchronous `POST` request to `/api/assess`. CloudFront identifies the `/api/*` path rule, disables edge caching, and forwards the HTTPS payload to the internet-facing Application Load Balancer (ALB) distributed across two public Availability Zones.
3. **Private Subnet Load Distribution:** The ALB accepts the request and distributes it over internal HTTP port 80 to healthy EC2 instances inside private application subnets across AZ-a and AZ-b. Because these instances have no public IP addresses or inbound internet routes, they accept connections exclusively originating from the ALB Security Group.
4. **Algorithmic Processing & Multi-AZ Database Writes:** The containerized Flask application processes the bio-telemetry data against its internal weighting matrix. It opens a TCP connection over private port 3306 to the primary Amazon RDS MySQL instance residing in the private database subnet. RDS commits the user record and synchronously mirrors the transaction across to its standby replica in the secondary AZ before returning a successful 200 JSON payload back through the ALB and CloudFront to the user's browser.
5. **Decoupled Telemetry Scraping:** Every HTTP lifecycle event triggers the internal `prometheus-flask-exporter` instrumentation to update metric counters and histograms. Concurrently, the dedicated monitoring EC2 instance queries the AWS EC2 API using attached IAM role permissions to discover active backend nodes tagged with `Role=backend`. Prometheus reaches out directly across the private VPC network (`192.168.0.0/16`) to scrape application metrics on port 80 (`/metrics`) and hardware performance metrics on port 9100 (`node_exporter`).
6. **Encrypted Administration:** Operators access internal dashboards without opening internet firewall rules. Running an SSM port-forwarding command opens a TLS-encrypted websocket tunnel directly to the monitoring host, binding Grafana (`localhost:3000`) and Prometheus (`localhost:9090`) securely to the local machine.

---

## Step-by-Step Deployment Guide

### Local Prerequisites & Secrets Setup

1. **Generate Session Secret Key:**
Generate a cryptographic token for Flask session integrity:
```bash
python3 -c 'import secrets; print(secrets.token_hex(32))'

```


2. **Configure GitHub Repository Secrets:**
Navigate to **Settings > Secrets and variables > Actions** in your GitHub repository and define the following secrets:
* `TF_API_TOKEN`: Terraform Cloud API token for remote state backend execution.
* `AWS_ACCESS_KEY_ID`: IAM programmatic access key with deployment permissions.
* `AWS_SECRET_ACCESS_KEY`: IAM programmatic secret access key.
* `AWS_REGION`: Target deployment region (e.g., `us-east-1`).
* `DB_USER`: Master RDS MySQL username (use `admin`; AWS reserves `root`).
* `DB_PASSWORD`: Master password for your RDS MySQL instance.
* `DB_NAME`: Database name (e.g., `neurogrid_db`).
* `SECRET_KEY`: Cryptographic secret string generated for Flask session protection.



---

### Automated Deployment Execution

Commit and push your code to the `main` branch:

```bash
git add .
git commit -m "Deploy complete production infrastructure and decoupled monitoring stack"
git push origin main

```

Upon push, GitHub Actions automatically executes the five pipeline stages:

1. **Terraform Provisioning:** Provisions the VPC network topology (6 subnets across 2 AZs), NAT Gateways, ALB, Multi-AZ RDS, Launch Templates, Auto Scaling Group, S3 bucket, CloudFront distribution with OAC, ECR repository, and the dedicated monitoring instance.
2. **Frontend Deployment:** Synchronizes `./frontend` static build assets to the private S3 bucket and triggers a global CloudFront cache invalidation (`/*`).
3. **Container Build & Registry Push:** Builds the production backend Docker container and pushes it to Amazon ECR tagged as `neurogrid-backend:latest`.
4. **ASG Orchestration via AWS SSM:**
* Packages `docker-compose.yml` and `init.sql` into a base64 deployment payload.
* Targets all instances in the Auto Scaling Group dynamically via AWS Systems Manager (`aws:autoscaling:groupName`).
* Injects production database credentials and ECR image tags into `/home/ubuntu/app/.env`.
* Runs ephemeral database migration containers against RDS MySQL and spins up the backend and Node Exporter services.


5. **Monitoring Deployment via AWS SSM:**
* Packages `monitoring/docker-compose.yml` and `monitoring/prometheus.yml`.
* Dispatches the payload directly to the dedicated monitoring instance (`tag:Role=monitoring`).
* Starts Prometheus and Grafana, immediately discovering and scraping ASG backend targets.



---

### Accessing the Application

Retrieve the CloudFront domain name from your Terraform outputs or the AWS Console:

```text
https://<CLOUDFRONT_DISTRIBUTION_DOMAIN>

```

* Navigating to `/` renders the S3-hosted client interface.
* Dynamic computations (`/api/*`) route transparently through the ALB to backend private instances.

---

## Secure Operational Access via AWS SSM

> **Note:** To execute the port-forwarding commands below, your local machine must have both the **AWS CLI** and the standalone **AWS Session Manager Plugin** installed and configured with appropriate IAM permissions.

Because ports `3000` (Grafana) and `9090` (Prometheus) are closed to the public internet and SSH port 22 is disabled, open encrypted tunnels from your local terminal using the AWS CLI and SSM Session Manager:

```bash
# Retrieve the Monitoring Host Instance ID
MON_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=monitoring" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

```

### 1. Access Grafana Dashboard (Port 3000)

```bash
aws ssm start-session \
  --target $MON_INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'

```

* **URL:** `http://localhost:3000`
* **Default Credentials:** User: `admin` | Password: `admin`

### 2. Access Prometheus Metrics Server (Port 9090)

```bash
aws ssm start-session \
  --target $MON_INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9090"],"localPortNumber":["9090"]}'

```

* **URL:** `http://localhost:9090`
* **Target Verification:** Navigate to `Status -> Targets` to inspect live health and latency metrics collected from all auto-discovered ASG nodes.

---

## Infrastructure Teardown

To clean up all cloud resources and prevent ongoing AWS charges:

1. Navigate to the **Actions** tab in your GitHub repository.
2. Select the **Terraform Destroy** workflow from the left sidebar.
3. Click **Run workflow** -> Select `main` -> Click **Run workflow**.

Alternatively, run Terraform destroy locally:

```bash
cd terraform
terraform destroy -auto-approve

```