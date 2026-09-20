# AWS Cloud Infrastructure with Terraform

Provisions a reproducible, version-controlled AWS environment (VPC, EC2,
S3, IAM) with a single `terraform apply` — no manual console clicking.

## Architecture

```
                    ┌─────────────────────────────┐
 Internet ──────────┤   Internet Gateway            │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │  VPC (10.0.0.0/16)             │
                    │  ┌───────────────────────────┐ │
                    │  │ Public Subnet (10.0.1.0/24)│ │
                    │  │  ┌─────────────────────┐  │ │
                    │  │  │  EC2 (Jenkins+k3s)  │  │ │
                    │  │  └─────────────────────┘  │ │
                    │  └───────────────────────────┘ │
                    └─────────────────────────────────┘
                                    │
                    IAM Role (EC2 → ECR access)
                    S3 bucket (artifacts / state)
```

## Why these choices

- **Single EC2 instance, not two** — keeps this a low-cost personal project;
  in production, Jenkins and the cluster would sit on separate machines.
- **IAM instance role instead of hardcoded AWS keys** — the EC2 instance
  authenticates to AWS services without any credentials stored on disk.
- **Security group locked to my own IP for SSH/admin ports** — only the
  app port (30080) is open to the world; everything else is restricted.
- **Remote state via S3** (see `main.tf` bucket resource) — makes the
  setup safe to collaborate on, since state isn't just a local file.

## Usage

```bash
terraform init
terraform plan   -var="my_ip=YOUR.IP.HERE/32" -var="key_pair_name=your-key"
terraform apply  -var="my_ip=YOUR.IP.HERE/32" -var="key_pair_name=your-key"
```

Outputs after apply: the instance's public IP, the Jenkins URL, and the
app URL (see `outputs.tf`).

Tear down when done to avoid ongoing AWS charges:
```bash
terraform destroy
```

## Files

| File            | Purpose                                              |
|-----------------|-------------------------------------------------------|
| `variables.tf`  | Configurable inputs (region, instance size, your IP)  |
| `main.tf`        | VPC, subnet, security group, IAM role, EC2 instance   |
| `outputs.tf`     | Prints the instance IP and service URLs after apply   |
| `user_data.sh`   | Bootstrap script — installs Docker, Jenkins, k3s, Trivy on first boot |

## What I'd improve next

- Split Jenkins and the k3s node onto separate instances for isolation
- Add a `terraform.tfvars.example` file for easier onboarding
- Move to remote state (S3 + DynamoDB lock) instead of local state
