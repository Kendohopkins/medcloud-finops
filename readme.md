# MedCloud-FinOps: Automated Cost Governance & Waste Elimination for Healthcare Workloads
  The aim of this project is to demonstrate how cloud technologies can improve the cost efficiency, security, and scalability of handling Protected Health Information (PHI), an area that can be costly and operationally challenging for hospitals, clinics, and other healthcare organizations. This project explores how the infrastructure and services implemented could be adapted for production environments to help streamline healthcare operations, reduce infrastructure costs, and improve the efficiency of managing patient data.

## Why this is different from generic FinOps

Most cost-optimization tools flag "idle EC2" with no awareness of what a workload actually is. This tool tags and evaluates healthcare infrastructure specifically — a test FHIR server idling at 2% CPU for two weeks is exactly the pattern that quietly costs health tech organizations alot of money, since these systems are often provisioned for peak load and left running continuously regardless of actual demand.

## Architecture

```
EventBridge (daily) ──► Lambda: waste scanner ──┬──► DynamoDB (waste log)
                                                  ├──► SNS ──► Email
                                                  └──► CloudWatch custom metrics ──► Grafana
```

Three independent scan passes per invocation, isolated so one failing scan doesn't take down the others:
1. **Idle clinical workloads** — EC2 instances tagged `WorkloadType` (fhir-server, dicom-processor, ehr-interface) running below a CPU threshold
2. **Orphaned EBS volumes** — unattached storage with no compute attached
3. **Oversized non-production instances** — large instance types in Staging/dev/Development environments

## Tech stack

| Component | Purpose |
|---|---|
| Terraform | Infrastructure as Code |
| Lambda (Python) | Three-pass waste scanner |
| DynamoDB | Persistent waste findings log |
| EventBridge | Daily scan schedule |
| SNS | Email alerting |
| CloudWatch custom metrics | Trend data for dashboards |
| Grafana (self-hosted, Docker) | Waste trend visualization |

## Setup

```bash
cp terraform.tfvars.example terraform.tfvars   # set aws_region and alert_email
terraform init
terraform apply
```
Confirm the SNS email subscription that arrives in your inbox.

**Grafana:**
```bash
docker run -d -p 3000:3000 --name grafana grafana/grafana
```
Add CloudWatch as a data source (Auth Provider: AWS SDK Default or a dedicated IAM profile with `CloudWatchReadOnlyAccess`), then build panels against the `MedCloudFinOps` namespace: `EstimatedMonthlySavingsUSD`, `TotalFindingsCount`, `FindingsCountByType`, `ScanErrorCount`.

## Testing performed

- **Orphaned EBS detection**: created a real unattached volume, invoked the scanner manually, confirmed the finding appeared in the Lambda response, DynamoDB, and the SNS email.
- **Idle clinical workload detection**: provisioned a tagged (`WorkloadType=fhir-server`) EC2 test instance via Terraform, stressed its CPU via SSH to confirm the raw CloudWatch metric and Grafana panel respond in real time, then let it return to idle and re-ran the scanner to confirm it was correctly flagged.
- **Pagination**: verified both `describe_instances` and `describe_volumes` calls use paginators rather than a single raw call, preventing silent under-reporting on accounts with more than ~1000 resources.
- **Persistence and alerting**: confirmed findings are durably logged to DynamoDB (not just returned in the Lambda response) and that SNS delivers a matching summary email.

## Challenges & Troubleshooting

Building this project wasn't completely straightforward. I ran into several AWS and Terraform issues along the way and had to troubleshoot them using the AWS CLI, Terraform, and a lot of testing.

| **Problem**                                      | **What caused it**                                                         | **How I fixed it**                                                                            |
| ------------------------------------------------ | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Terraform reported an **"empty archive"** error  | The Lambda folder existed, but the `index.py` file was missing             | Checked the folder using the CLI, created the missing file, and ran Terraform again           |
| IAM returned a **`NoSuchEntity`** error          | The IAM username didn't match the name I was using in my AWS CLI profile   | Used the AWS CLI to find the correct IAM username and updated the profile                     |
| AWS returned **`InvalidClientTokenId`**          | The Access Key ID and Secret Access Key came from different key pairs      | Created a new access key pair and configured the AWS CLI again                                |
| AWS CLI couldn't connect to the **STS endpoint** | The AWS region had been configured incorrectly                             | Fixed the region and output settings using `aws configure set`                                |
| Security group creation failed                   | The description contained a special character (`—`) that AWS didn't accept | Replaced it with a normal hyphen (`-`)                                                        |
| EC2 **SSM Session Manager** wouldn't connect     | The EC2 instance wasn't successfully registering with SSM                  | Used a Terraform-generated SSH key instead, which gave me direct access to the test instance  |
| The project started with separate scripts        | Different scanners had separate logic, logging, and no pagination          | Combined them into one Lambda with shared DynamoDB logging, SNS alerts, and proper pagination |

### What I learned

These issues gave me practical experience troubleshooting **AWS IAM, EC2, SSM, Terraform, AWS CLI, Lambda, and AWS API errors**.

More importantly, I learned to **check the actual AWS resources and error messages before making assumptions**, and to simplify the architecture when a particular approach was causing unnecessary complexity.


## Known limitations

- CPU utilization alone is a naive idle signal — a memory- or I/O-bound workload could show low CPU while still doing real work.
- Cost estimates use hardcoded hourly rates, not the AWS Pricing API — accurate for relative comparison, not billing-accurate.
- Detection depends on consistent tagging discipline; untagged infrastructure isn't evaluated.

## Possible extensions

- Call the AWS Pricing API for accurate, region-aware cost estimates
- Add network I/O / request-count checks to reduce idle-detection false positives
- Add auto-remediation for the safest finding type (e.g. auto-delete EBS volumes unattached 30+ days, dry-run first)

## Cleanup

```bash
terraform destroy
```
