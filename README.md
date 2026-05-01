# TravelMemory — AWS Infrastructure Automation

A MERN stack travel journal application deployed on AWS using **Terraform** (infrastructure provisioning) and **Ansible/shell scripts** (configuration management).

---

## Live Application

**URL:** http://13.40.66.13

---

## Architecture Overview

```
                          ┌─────────────────────────────────┐
                          │           AWS VPC                │
                          │        (10.0.0.0/16)             │
                          │                                  │
          Internet        │  Public Subnet (eu-west-2a)      │
      ────────────────►   │  ┌───────────────────────────┐   │
                          │  │   Web Server (t2.micro)    │   │
                          │  │   IP: 13.40.66.13          │   │
                          │  │                           │   │
                          │  │  nginx (:80)              │   │
                          │  │    ├── React frontend (/)  │   │
                          │  │    └── Express API (/api/) │   │
                          │  │  Node.js/PM2 (:3001)      │   │
                          │  └────────────┬──────────────┘   │
                          │               │                  │
                          │  Private Subnet (eu-west-2b)     │
                          │  ┌────────────▼──────────────┐   │
                          │  │  DB Server (t2.micro)      │   │
                          │  │  IP: 10.0.2.5 (private)    │   │
                          │  │  MongoDB 7.0 (:27017)      │   │
                          │  └───────────────────────────┘   │
                          └─────────────────────────────────┘
```

**Traffic flow:**
- HTTP requests hit nginx on the web server
- Static React assets served directly from `/opt/travelmemory/frontend/build`
- API calls (`/api/*`) are reverse-proxied to Express on port 3001
- Express connects to MongoDB on the private subnet IP over port 27017
- DB server has no public IP — only reachable from within the VPC

---

## Repository Structure

```
TravelMemory/
├── terraform/                  # AWS infrastructure as code
│   ├── main.tf                 # Provider config (AWS, TLS, local)
│   ├── variables.tf            # All input variables
│   ├── vpc.tf                  # VPC, subnets, IGW, NAT gateway, route tables
│   ├── security_groups.tf      # Web SG and DB SG
│   ├── iam.tf                  # IAM roles for EC2 instances
│   ├── ec2.tf                  # Web and DB EC2 instances + key pair
│   ├── outputs.tf              # Public IP, SSH commands, app URL
│   └── terraform.tfvars.example
│
├── ansible/                    # Configuration management
│   ├── ansible.cfg             # Ansible settings
│   ├── inventory/hosts.ini     # Static inventory (web + db hosts)
│   ├── group_vars/
│   │   ├── all.yml             # Shared variables (repo URL, DB name)
│   │   ├── webservers.yml      # Web server variables
│   │   └── dbservers.yml       # DB server variables
│   ├── playbooks/
│   │   ├── site.yml            # Master playbook
│   │   ├── webserver.yml       # Node.js, PM2, nginx, React build
│   │   └── database.yml        # MongoDB install, users, auth, firewall
│   └── templates/
│       ├── mongod.conf.j2      # MongoDB config template
│       ├── nginx.conf.j2       # nginx reverse proxy config
│       ├── backend.env.j2      # Backend .env (MONGO_URI, PORT)
│       └── frontend.env.j2     # Frontend .env (REACT_APP_BACKEND_URL)
│
├── scripts/                    # Direct SSH deployment scripts (Windows)
│   ├── setup-db.sh             # MongoDB setup script (runs on DB server)
│   └── setup-web.sh            # Web server setup script
│
├── Makefile                    # Convenience commands for full deploy pipeline
├── backend/                    # Express.js API
└── frontend/                   # React application
```

---

## Part 1: Infrastructure — Terraform

### AWS Resources Provisioned

| Resource | Details |
|---|---|
| VPC | 10.0.0.0/16 with DNS enabled |
| Public Subnet | eu-west-2a — 10.0.1.0/24, auto-assigns public IPs |
| Private Subnet | eu-west-2b — 10.0.2.0/24, no public IPs |
| Internet Gateway | Attached to VPC for public subnet outbound |
| NAT Gateway | In public subnet, allows private subnet outbound |
| Public Route Table | Default route → Internet Gateway |
| Private Route Table | Default route → NAT Gateway |
| Web Security Group | Ingress: 80/443 from 0.0.0.0/0, 22 from admin IP only |
| DB Security Group | Ingress: 27017 from web SG only, 22 from web SG only |
| Web EC2 (t2.micro) | Ubuntu 22.04, public subnet, IAM role with SSM + CloudWatch |
| DB EC2 (t2.micro) | Ubuntu 22.04, private subnet, IAM role with CloudWatch |
| RSA Key Pair | 4096-bit, Terraform-managed, private key saved locally |

### Prerequisites

```bash
# Install Terraform >= 1.5.0
# Configure AWS CLI
aws configure
# Verify authentication
aws sts get-caller-identity
```

### Deploy Infrastructure

```bash
cd terraform

# 1. Copy and fill in your values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   your_ip_cidr  = "$(curl -s https://checkip.amazonaws.com)/32"
#   mongo_admin_password = "your_strong_password"
#   mongo_app_password   = "your_strong_password"

# 2. Initialise providers
terraform init

# 3. Preview changes
terraform plan

# 4. Apply
terraform apply
```

### Outputs

```
application_url            = "http://<web-public-ip>"
web_server_public_ip       = "<ip>"
db_server_private_ip       = "<ip>"
ssh_command_web            = "ssh -i ansible/travelmemory-key.pem ubuntu@<ip>"
ssh_command_db_via_bastion = "ssh -i ansible/travelmemory-key.pem -J ubuntu@<web-ip> ubuntu@<db-ip>"
```

---

## Part 2: Configuration — Ansible

### What the Playbooks Do

**`database.yml`**
1. Installs MongoDB 7.0 from the official MongoDB apt repo
2. Configures `/etc/mongod.conf` — binds to all interfaces (firewall restricts access)
3. Starts MongoDB, creates the admin superuser
4. Enables authentication, restarts, then creates the `travelmemory_user` app user
5. Configures UFW — allows 22 (SSH) and 27017 only from VPC CIDR (10.0.0.0/16)
6. Hardens SSH — disables root login and password authentication

**`webserver.yml`**
1. Installs Node.js 18.x and npm from NodeSource
2. Installs PM2 process manager globally
3. Clones the TravelMemory GitHub repository to `/opt/travelmemory`
4. Installs backend npm dependencies, writes `.env` with `MONGO_URI` and `PORT`
5. Installs frontend npm dependencies, writes `.env` with `REACT_APP_BACKEND_URL`
6. Builds the React production bundle (`CI=false npm run build`)
7. Starts the backend with PM2 (`--cwd` set so dotenv finds `.env`)
8. Configures nginx — serves React on `/`, proxies `/api/` to Express on `:3001`
9. Configures UFW — allows 22, 80, 443; denies everything else inbound
10. Hardens SSH — disables root login and password authentication

### Run with Ansible (Linux/Mac)

```bash
# Install dependencies
pip install ansible
ansible-galaxy collection install community.mongodb

# Update inventory with Terraform outputs
cd ansible
# Edit inventory/hosts.ini with actual IPs from terraform output

# Ping all hosts
ansible all -m ping

# Run everything
ansible-playbook playbooks/site.yml

# Or run individual playbooks
ansible-playbook playbooks/database.yml
ansible-playbook playbooks/webserver.yml
```

### Or use the Makefile (full pipeline)

```bash
make tf-init       # terraform init
make tf-plan       # terraform plan
make tf-apply      # terraform apply
make update-inventory  # auto-fill IPs from terraform output
make ansible-all   # run all ansible playbooks

# One command for everything after tfvars is configured:
make deploy
```

---

## Security Design

| Concern | Implementation |
|---|---|
| DB not publicly accessible | DB EC2 in private subnet, no public IP |
| MongoDB port locked down | SG rule allows 27017 only from web server's SG |
| SSH restricted | Web server: 22 only from admin IP. DB: 22 only through web SG (bastion pattern) |
| Root login disabled | `PermitRootLogin no` + `PasswordAuthentication no` in sshd_config |
| OS-level firewall | UFW enabled on both servers with default-deny inbound |
| EBS volumes encrypted | `encrypted = true` on all root block devices |
| IAM least privilege | Separate roles per instance; SSM read-only + CloudWatch only |
| Secrets not in git | `terraform.tfvars` and `*.pem` are in `.gitignore` |

---

## Application Configuration

### Backend `.env` (auto-generated by deployment)

```
PORT=3001
MONGO_URI=mongodb://travelmemory_user:<password>@<db-private-ip>:27017/travelmemory
```

### Frontend `.env` (auto-generated by deployment)

```
REACT_APP_BACKEND_URL=http://<web-public-ip>/api
```

### API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/hello` | Health check |
| GET | `/trip` | List all trips |
| GET | `/trip/:id` | Get trip by ID |
| POST | `/trip` | Add a new trip |

### Sample POST body

```json
{
    "tripName": "Incredible India",
    "startDateOfJourney": "19-03-2022",
    "endDateOfJourney": "27-03-2022",
    "nameOfHotels": "Hotel Namaste, Backpackers Club",
    "placesVisited": "Delhi, Kolkata, Chennai, Mumbai",
    "totalCost": 800000,
    "tripType": "leisure",
    "experience": "An unforgettable journey through India's rich culture.",
    "image": "https://example.com/image.jpg",
    "shortDescription": "India is a wonderful country with rich culture and good people.",
    "featured": true
}
```

---

## Tear Down

```bash
cd terraform
terraform destroy
```

This removes all AWS resources — both EC2 instances, VPC, subnets, NAT gateway, EIPs, security groups, and IAM roles.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18, React Router 6, Axios |
| Backend | Node.js 18, Express 4, Mongoose 7 |
| Database | MongoDB 7.0 |
| Process manager | PM2 |
| Reverse proxy | nginx |
| IaC | Terraform >= 1.5, AWS provider ~> 5.0 |
| Config management | Ansible (playbooks + Jinja2 templates) |
| Cloud provider | AWS (eu-west-2) |
| OS | Ubuntu 22.04 LTS |
