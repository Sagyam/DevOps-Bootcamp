# Cloud Computing

## 1. Cloud Fundamentals & AWS Global Infrastructure

### Q1: Explain Regions, Availability Zones (AZs), and Edge Locations.
* **Answer:**
  * **Region:** A physical geographic location around the world (e.g., `us-east-1` N. Virginia, `eu-west-1` Ireland) containing multiple isolated datacenters.
  * **Availability Zone (AZ):** One or more discrete datacenters with redundant power, networking, and connectivity within a Region (e.g., `us-east-1a`, `us-east-1b`). AZs are connected via ultra-low latency private fiber networks to provide high availability and fault tolerance.
  * **Edge Locations:** Datacenter endpoints used by CloudFront (CDN) and Route 53 to cache content closer to end users worldwide to reduce latency.

---

### Q2: What is the AWS Shared Responsibility Model?
* **Answer:**
  * **Security OF the Cloud (AWS Responsibility):** AWS protects the physical infrastructure, hardware, host virtualization software, physical facilities, and global networking across regions and AZs.
  * **Security IN the Cloud (Customer Responsibility):** Customer manages customer data, IAM policies, OS configuration/patching on EC2, network firewalls (Security Groups/NACLs), application code, and data encryption (at rest and in transit).

---

## 2. IAM (Identity & Access Management)

### Q3: Explain IAM Users, Groups, Roles, and Policies. What is the Principle of Least Privilege?
* **Answer:**
  * **IAM User:** An identity representing a specific person or service requiring long-term credentials (password, access keys).
  * **IAM Group:** A collection of IAM users used to assign permissions to multiple users at once.
  * **IAM Role:** An identity with specific permissions that is assumed temporarily by a trusted entity (e.g., an EC2 instance, Lambda function, or federated user). Does not use long-term static passwords/keys; uses temporary STS tokens.
  * **IAM Policy:** A JSON document explicitly defining allowed or denied actions (`Allow`/`Deny`), resources (`Resource`), and conditions (`Condition`).
  * **Principle of Least Privilege:** Granting users/services only the absolute minimum permissions necessary to perform their required tasks, and nothing more.

---

### Q4: Why should applications running on EC2 or Lambda use IAM Roles instead of hardcoded AWS Access Keys?
* **Answer:**
  * Hardcoding `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in application code or configuration files risks credential leakage (e.g., accidental Git commits).
  * **IAM Roles** use AWS Security Token Service (STS) to automatically deliver and rotate short-lived temporary credentials to the instance metadata service (`IMDSv2`). Zero manual secret rotation is required.

---

## 3. VPC (Virtual Private Cloud) & Networking

### Q5: Explain the components of a secure VPC architecture: Public Subnet, Private Subnet, Internet Gateway (IGW), and NAT Gateway.
* **Answer:**
  * **VPC:** An isolated virtual network dedicated to your AWS account.
  * **Public Subnet:** A subnet whose Route Table contains a direct route (`0.0.0.0/0`) to an **Internet Gateway (IGW)**. Resources have public IPs and can send/receive direct internet traffic (e.g., Public Load Balancers, Bastion hosts).
  * **Private Subnet:** A subnet whose Route Table does **not** route to an IGW. Resources have only private IPs and cannot be directly accessed from the internet (e.g., Application backends, databases).
  * **NAT Gateway (Network Address Translation):** Located in a Public Subnet. Allows instances in Private Subnets to make outbound internet connections (for software updates, external API calls) while blocking inbound connections initiated from the internet.

---

### Q6: What is the difference between Security Groups and Network ACLs (NACLs)?
* **Answer:**
  | Feature | Security Group | Network ACL (NACL) |
  | :--- | :--- | :--- |
  | **Level** | Instance / Network Interface (ENI) level | Subnet level |
  | **State** | **Stateful** (Return traffic is automatically allowed regardless of inbound rules) | **Stateless** (Return traffic must be explicitly allowed in outbound rules) |
  | **Rule Type** | Supports **ALLOW** rules only | Supports both **ALLOW** and **DENY** rules |
  | **Rule Evaluation** | All rules evaluated before granting access | Processed in strict **numerical order** (lowest number first) |

---

## 4. Compute & Storage (EC2, S3, EBS)

### Q7: Compare EC2 purchasing options: On-Demand, Spot Instances, and Reserved Instances / Savings Plans.
* **Answer:**
  * **On-Demand:** Pay by the second with no long-term commitment. Maximum flexibility, highest hourly cost. Best for unpredictable workloads or short-term dev/testing.
  * **Spot Instances:** Bid on unused AWS spare capacity at discounts up to 90% off On-Demand. AWS can reclaim instances with a 2-minute interruption notice. Ideal for stateless, fault-tolerant batch jobs, CI/CD runners, and container nodes.
  * **Reserved Instances / Savings Plans:** 1-year or 3-year commitment to a consistent amount of compute usage in exchange for up to 72% discount. Best for steady-state production workloads.

---

### Q8: What are the differences between Amazon S3, EBS, and EFS?
* **Answer:**
  * **Amazon S3 (Simple Storage Service):** Highly scalable **Object Storage** accessible via REST API/HTTPS. Infinite capacity, 99.999999999% (11 9's) durability. Ideal for static assets, backups, and data lakes.
  * **Amazon EBS (Elastic Block Store):** High-performance **Block Storage** mounted as a virtual hard disk to a single EC2 instance in the same AZ. Ideal for OS boot volumes and relational databases.
  * **Amazon EFS (Elastic File System):** Managed NFS **File Storage** that can be concurrently mounted by hundreds of EC2 instances and containers across multiple AZs.

---

## 5. Managed Databases & Observability

### Q9: What is the difference between Amazon RDS Multi-AZ Deployment and Read Replicas?
* **Answer:**
  * **Multi-AZ Deployment (High Availability & Disaster Recovery):**
    - Synchronously replicates database writes to a standby replica in a second AZ.
    - Standby replica is passive (does not serve read traffic).
    - In the event of primary database failure, AWS triggers an automatic failover to the standby in ~60 seconds with zero manual DNS changes.
  * **Read Replicas (Scalability & Performance):**
    - Asynchronously replicates data to one or more active read-only instances.
    - Serves read-heavy application traffic to reduce load on the primary DB.
    - Can be promoted to a standalone database if needed, but not an automatic failover mechanism.

---

### Q10: Explain CloudWatch vs. CloudTrail.
* **Answer:**
  * **Amazon CloudWatch (Performance & Monitoring):** Focuses on **operational health**. Collects metrics (CPU, disk I/O, network), monitors log files (`/aws/lambda/`, application logs), and triggers automated alarms (e.g., auto-scale out, send SNS email).
  * **AWS CloudTrail (Auditing & Governance):** Focuses on **API activity tracking**. Records who did what, when, and from which IP address across your AWS account (e.g., "User Alice deleted an S3 bucket at 14:22 via AWS Console").