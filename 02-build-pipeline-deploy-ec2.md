# Lab 02 — Build a CI/CD Pipeline that Deploys to EC2

## Objective

Build a complete, production-like CI/CD pipeline: push code to GitHub → CodeBuild tests it → CodeDeploy ships it to a real EC2 instance. This is how real-world deployments work.

**What you'll build:**

```
GitHub → CodePipeline → CodeBuild (test) → CodeDeploy → EC2 (live app)
```

**Time:** ~60 min

---

## Prerequisites

- Completed Lab 01 (your GitHub repo with the sample app)
- AWS Console access with AdministratorAccess
- Region: **ap-southeast-1** (Singapore)

---

## Part A: Launch an EC2 Instance (15 min)

You need a real server to deploy to.

### A1. Create an IAM Role for EC2

CodeDeploy needs the EC2 instance to have an agent that communicates with AWS.

1. Go to **IAM Console** → **Roles** → **Create role**
2. Trusted entity: **AWS service** → **EC2**
3. Add permissions:
   - Search and select: `AmazonEC2RoleforAWSCodeDeploy`
   - Search and select: `AmazonSSMManagedInstanceCore`
4. Role name: `dost-ptri-ec2-codedeploy-role`
5. Click **Create role**

### A2. Launch the EC2 Instance

1. Go to **EC2 Console** → **Launch instance**
2. Configure:

| Setting | Value |
|---------|-------|
| Name | `dost-ptri-day6-app-server` |
| AMI | **Amazon Linux 2023** |
| Instance type | `t2.micro` (free tier) |
| Key pair | Create new → `dost-ptri-day6-key` → Download |
| Network | Default VPC, public subnet |
| Auto-assign public IP | **Enable** |
| Security group | Create new: `dost-ptri-day6-sg` |
| Inbound rules | SSH (22) from Anywhere, HTTP (8080) from Anywhere |
| IAM instance profile | Select `dost-ptri-ec2-codedeploy-role` |

3. Under **Advanced details** → **User data**, paste:

```bash
#!/bin/bash
yum update -y
yum install -y python3 python3-pip ruby wget
pip3 install flask

# Install CodeDeploy Agent
cd /home/ec2-user
wget https://aws-codedeploy-ap-southeast-1.s3.ap-southeast-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl start codedeploy-agent
systemctl enable codedeploy-agent
```

4. Click **Launch instance**
5. Wait for instance state: **Running** ✅
6. Note the **Public IPv4 address** — you'll need it later

### A3. Add a Tag for CodeDeploy

1. Select your instance → **Tags** tab → **Manage tags**
2. Add tag:
   - Key: `DeployGroup`
   - Value: `dost-ptri-day6`
3. Save

> 💡 CodeDeploy uses this tag to find which instances to deploy to.

---

## Part B: Create CodeDeploy Application (10 min)

### B1. Create IAM Role for CodeDeploy Service

1. Go to **IAM** → **Roles** → **Create role**
2. Trusted entity: **AWS service** → **CodeDeploy**
3. Use case: **CodeDeploy**
4. Permission auto-selected: `AWSCodeDeployRole`
5. Role name: `dost-ptri-codedeploy-service-role`
6. Click **Create role**

### B2. Create the CodeDeploy Application

1. Go to **CodeDeploy Console** → **Applications** → **Create application**
2. Application name: `dost-ptri-day6-app`
3. Compute platform: **EC2/On-premises**
4. Click **Create application**

### B3. Create a Deployment Group

1. Inside your application → **Create deployment group**
2. Configure:

| Setting | Value |
|---------|-------|
| Deployment group name | `dost-ptri-day6-deploy-group` |
| Service role | Select `dost-ptri-codedeploy-service-role` |
| Deployment type | **In-place** |
| Environment configuration | **Amazon EC2 instances** |
| Tag group: Key | `DeployGroup` |
| Tag group: Value | `dost-ptri-day6` |
| Agent configuration | **Now and schedule updates** |
| Deployment settings | `CodeDeployDefault.AllAtOnce` |
| Load balancer | ❌ Uncheck "Enable load balancing" |

3. Click **Create deployment group**

---

## Part C: Create the Pipeline (15 min)

### C1. Create GitHub Connection

1. Go to **CodePipeline** → **Settings** → **Connections**
2. Click **Create connection** → **GitHub**
3. Connection name: `dost-ptri-github`
4. Authorize and install on your repo
5. Status: **Available** ✅

### C2. Create CodeBuild Project

1. Go to **CodeBuild** → **Create build project**

| Setting | Value |
|---------|-------|
| Project name | `dost-ptri-day6-build` |
| Source | GitHub (via connection) → your repo |
| Environment | Managed image, Amazon Linux, Standard, `5.0` |
| Buildspec | Use a buildspec file |
| Artifacts | **Amazon S3** |
| Bucket | Create one: `dost-ptri-day6-artifacts-YOURNAME` |
| Artifacts packaging | **Zip** |

2. Click **Create build project**

### C3. Create CodePipeline

1. Go to **CodePipeline** → **Create pipeline**

| Setting | Value |
|---------|-------|
| Pipeline name | `dost-ptri-day6-pipeline` |
| Pipeline type | V2 |
| Service role | New service role |

2. **Source stage:**

| Setting | Value |
|---------|-------|
| Provider | GitHub (via connection) |
| Connection | `dost-ptri-github` |
| Repository | Your `dost-ptri-day6-cicd` repo |
| Branch | `main` |

3. **Build stage:**

| Setting | Value |
|---------|-------|
| Provider | AWS CodeBuild |
| Project | `dost-ptri-day6-build` |

4. **Deploy stage:**

| Setting | Value |
|---------|-------|
| Provider | **AWS CodeDeploy** |
| Application name | `dost-ptri-day6-app` |
| Deployment group | `dost-ptri-day6-deploy-group` |

5. Click **Create pipeline**

---

## Part D: Watch the Full Deployment (10 min)

The pipeline triggers immediately after creation.

### Watch each stage:

1. **Source** ✅ — pulls code from GitHub
2. **Build** ✅ — CodeBuild runs `buildspec.yml`:
   - Installs dependencies
   - Runs `pytest` (2 tests pass)
   - Packages app into ZIP
3. **Deploy** ✅ — CodeDeploy runs `appspec.yml` on your EC2:
   - `stop_server.sh` — stops old app
   - Copies files to `/opt/dost-ptri-app`
   - `install_dependencies.sh` — installs Flask
   - `start_server.sh` — starts the app
   - `validate_service.sh` — curls `/health` to confirm

### Test the live app:

```bash
curl http://YOUR-EC2-PUBLIC-IP:8080/
```

Response:
```json
{"message": "DOST PTRI Day 6 — CI/CD Sample App", "status": "running"}
```

```bash
curl http://YOUR-EC2-PUBLIC-IP:8080/health
```

Response:
```json
{"status": "healthy"}
```

> 🎉 **Your app is live on EC2, deployed automatically via CI/CD!**

---

## Part E: Push a Change — See Auto-Deploy (10 min)

### Edit `app.py` locally — add a version endpoint:

```python
@app.route("/version")
def version():
    return jsonify({"version": "2.0.0", "deployed_by": "CodeDeploy"})
```

### Push to GitHub:

```bash
git add app.py
git commit -m "feat: add version endpoint"
git push
```

### Watch the pipeline:

1. Source ✅ → Build ✅ → Deploy ✅
2. Test:

```bash
curl http://YOUR-EC2-PUBLIC-IP:8080/version
```

```json
{"version": "2.0.0", "deployed_by": "CodeDeploy"}
```

**Zero manual intervention. Push code → live on server. That's CI/CD.**

---

## What's Happening Behind the Scenes

```
┌─────────┐     ┌──────────────┐     ┌───────────┐     ┌────────────┐     ┌─────┐
│  You    │────→│  GitHub      │────→│CodePipeline│────→│ CodeBuild  │────→│Code │
│git push │     │  (webhook)   │     │(orchestrate)│    │(build+test)│     │Deploy│
└─────────┘     └──────────────┘     └───────────┘     └───────────┘     └──┬──┘
                                                                              │
                                                                              ↓
                                                                     ┌──────────────┐
                                                                     │   EC2 Server  │
                                                                     │──────────────│
                                                                     │ 1. Stop old   │
                                                                     │ 2. Copy files  │
                                                                     │ 3. Install deps│
                                                                     │ 4. Start app   │
                                                                     │ 5. Health check│
                                                                     └──────────────┘
```

### The scripts in action:

| Script | What it does on EC2 | Why it matters |
|--------|--------------------|----|
| `stop_server.sh` | Kills the old process | Zero-downtime prep |
| `install_dependencies.sh` | `pip install` on the server | Fresh deps every deploy |
| `start_server.sh` | Starts app in background | App goes live |
| `validate_service.sh` | Curls `/health` | Confirms deploy succeeded |

If `validate_service.sh` fails → CodeDeploy marks deployment as **failed** → pipeline shows ❌ → you know immediately.

---

## Clean Up

Delete in this order:

1. **CodePipeline** → Delete pipeline
2. **CodeDeploy** → Delete deployment group → Delete application
3. **CodeBuild** → Delete project
4. **EC2** → Terminate instance
5. **S3** → Empty and delete artifact bucket
6. **IAM** → Delete both roles (`ec2-codedeploy-role`, `codedeploy-service-role`)
7. **CodePipeline Settings** → Delete GitHub connection

---

## ✅ Lab Complete!

You built a real production-like CI/CD pipeline:

| Component | What it does |
|-----------|-------------|
| GitHub | Source control — triggers pipeline on push |
| CodePipeline | Orchestrates the entire workflow |
| CodeBuild | Builds, tests, packages (reads `buildspec.yml`) |
| CodeDeploy | Deploys to EC2 (reads `appspec.yml` + runs scripts) |
| EC2 | Your production server running the app |

**This is exactly how companies deploy software to production.**

---

**Next → [Lab 03: CloudFormation Basic — S3 Bucket](./03-cloudformation-basic.md)**
