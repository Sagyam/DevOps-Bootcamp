# Infrastructure as Code

## 1. Fundamentals of IaC & Terraform

### Q1: What is Infrastructure as Code (IaC)? Explain Declarative vs. Imperative approaches.
* **Answer:**
  * **Infrastructure as Code (IaC):** Managing and provisioning infrastructure through machine-readable definition files rather than manual configuration via web consoles or interactive CLI commands.
  * **Declarative (e.g., Terraform, CloudFormation, Kubernetes YAML):**
    - You define the **desired end-state** ("I want 3 EC2 instances and 1 VPC").
    - The tool calculates the current state, computes the difference (delta), and applies the necessary changes to reach the desired state.
  * **Imperative (e.g., AWS CLI scripts, Bash, Python boto3):**
    - You define the **explicit step-by-step instructions** to create the infrastructure ("Create VPC, then wait, then create subnet, then loop 3 times to spin up VMs").
    - Does not track state automatically; harder to manage drift and idempotency.

---

### Q2: Explain the primary Terraform CLI Workflow commands.
* **Answer:**
  1. `terraform init`: Initializes the working directory, downloads required provider plugins (e.g., AWS, Azure) and child modules, and configures the backend.
  2. `terraform validate`: Validates syntax and internal consistency of configuration files without accessing remote APIs.
  3. `terraform fmt`: Automatically reformats Terraform configuration files to follow canonical HCL style and indentation.
  4. `terraform plan`: Compares the desired configuration against the current state and generates an execution plan showing actions (`+ create`, `~ update in-place`, `- destroy`).
  5. `terraform apply`: Executes the actions proposed in the plan to create, update, or destroy real infrastructure.
  6. `terraform destroy`: Destroys all managed infrastructure declared in the Terraform workspace.

---

## 2. Terraform State Management

### Q3: What is the Terraform State file (`terraform.tfstate`) and why is it needed?
* **Answer:**
  * The state file is a JSON file that maps your Terraform code definitions to real-world cloud resource IDs and attributes.
  * **Why it is needed:**
    - **Resource Tracking:** Stores metadata and resource dependencies.
    - **Performance:** Caches cloud resource attributes so Terraform doesn't have to query cloud APIs for every resource on every plan.
    - **Drift Detection:** Compares real-world resources with state and code to detect manual out-of-band changes.

---

### Q4: What is Remote State and State Locking? How do you configure it in AWS?
* **Answer:**
  * **Problem with Local State:** Storing `terraform.tfstate` locally on a developer's laptop causes state conflicts, exposes plain-text secrets, and prevents team collaboration.
  * **Remote State:** Stores the state file in a central, secure, shared storage backend (e.g., Amazon S3, Terraform Cloud).
  * **State Locking:** Prevents two team members or CI pipelines from running `terraform apply` simultaneously, avoiding race conditions and state corruption.
* **Standard AWS Backend Configuration:**
  ```hcl
  terraform {
    required_version = ">= 1.5.0"
    backend "s3" {
      bucket         = "my-company-terraform-state-prod"
      key            = "vpc/terraform.tfstate"
      region         = "us-east-1"
      dynamodb_table = "terraform-state-locks" # Provides state locking
      encrypt        = true
    }
  }
  ```

---

### Q5: Sensitive secrets (e.g., database passwords) are stored in plain text in `terraform.tfstate`. How do you protect it?
* **Answer:**
  1. Never commit `.tfstate` files to version control (add to `.gitignore`).
  2. Use a secure remote backend (e.g., Amazon S3) with server-side encryption enabled (KMS).
  3. Enforce strict IAM policies restricting S3 bucket access to authorized CI/CD roles only.
  4. Enable S3 bucket versioning to recover from accidental state corruption or deletion.

---

## 3. Variables, Locals, Outputs & Modules

### Q6: Explain the difference between Input Variables, Local Values (`locals`), and Outputs.
* **Answer:**
  * **Input Variables (`variable "name" {}`):** Parameters passed into a module or configuration to customize behavior without editing code (like function arguments). Can have default values, types, and descriptions.
  * **Local Values (`locals {}`):** Internal temporary variables within a module used to avoid repeating expressions or compute complex transformations (like local constants).
  * **Outputs (`output "name" {}`):** Exposes values from a module (like return values in functions) to print to the console or share with other modules/workspaces.

---

### Q7: What are Terraform Modules and why should you use them?
* **Answer:**
  * A **module** is a container for multiple resources that are used together. Any folder containing `.tf` files is a module (the root module or child modules).
  * **Benefits:**
    - **Reusability:** Write a standard VPC or microservice module once and reuse it across `dev`, `staging`, and `prod` environments.
    - **Standardization:** Enforces organizational security standards and tagging conventions.
    - **Maintainability:** Reduces duplication and keeps code DRY (Don't Repeat Yourself).

---

### Q8: What is the difference between `count` and `for_each` in Terraform?
* **Answer:**
  * **`count`:** Creates multiple instances based on an integer index (`count.index`).
    - *Drawback:* If you remove an item from the middle of a list used in `count`, Terraform will destroy and recreate all subsequent resources because their index positions shifted.
  * **`for_each`:** Iterates over a map or set of strings using explicit keys (`each.key`, `each.value`).
    - *Advantage:* Adding or removing an item only impacts that specific resource key without affecting neighboring resources. Always preferred over `count` when managing collections of named resources.

---

## 4. Troubleshooting & Best Practices

### Q9: What is Configuration Drift and how does Terraform handle it?
* **Answer:**
  * **Configuration Drift** occurs when real-world cloud resources are modified manually (e.g., someone changes a Security Group rule in the AWS Web Console) without updating the Terraform code.
  * **Detection:** When you run `terraform plan` or `terraform refresh`, Terraform queries the cloud provider API, refreshes the state file, compares it with your code, and highlights the drift.
  * **Remediation:** Running `terraform apply` will overwrite the manual changes and restore the infrastructure back to the declared state in code.

---

### Q10: How do you import existing infrastructure that was created manually into Terraform?
* **Answer:**
  1. Write the corresponding Terraform resource block in your `.tf` file:
     ```hcl
     resource "aws_s3_bucket" "legacy_bucket" {
       bucket = "my-manually-created-bucket-2024"
     }
     ```
  2. Run `terraform import`:
     ```bash
     terraform import aws_s3_bucket.legacy_bucket my-manually-created-bucket-2024
     ```
  3. *(Terraform 1.5+)* Alternatively, use the declarative `import` block:
     ```hcl
     import {
       to = aws_s3_bucket.legacy_bucket
       id = "my-manually-created-bucket-2024"
     }
     ```
  4. Run `terraform plan` to ensure your configuration attributes match the imported resource state with zero unintended changes.