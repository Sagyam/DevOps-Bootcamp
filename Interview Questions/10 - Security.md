## Security

### 1. What is the principle of least privilege?

- Give every user, service, and pipeline only the access it needs to do its job. Nothing extra.
- Example: a CI job that uploads files to one S3 bucket should not have full S3 admin rights.
- Why it matters: if a key or password leaks, the damage stays small.
- In practice: IAM roles with narrow policies, Kubernetes RBAC, and reviewing permissions regularly.

### 2. What is the difference between authentication and authorization?

- Authentication = proving who you are. Password, SSH key, token, MFA.
- Authorization = what you are allowed to do once you are in. Roles, permissions, policies.
- Always in that order: first prove identity, then check permissions.
- Example: logging in to AWS is authentication. Whether you can delete an EC2 instance is authorization.

### 3. How do you manage secrets (passwords, API keys, tokens)?

- Never put them in code, Dockerfiles, or Git. Not even in a private repo.
- Store them in a secret manager: GitHub Actions secrets, Jenkins credentials, AWS Secrets Manager, HashiCorp Vault, or Infisical.
- Inject them at runtime as environment variables or mounted files.
- Rotate them on a schedule, and make sure logs mask them.
- Better still: avoid long-lived keys. Use OIDC so the pipeline gets a short-lived token from AWS instead of storing an access key.

### 4. A developer accidentally committed a secret to Git. What do you do?

- Treat it as leaked the moment it was pushed. Rotate or revoke the secret first, before anything else.
- Deleting the file in a new commit is not enough. The secret is still in the Git history.
- Check access logs to see if the secret was used.
- Fix the process: add secret scanning (gitleaks, GitHub secret scanning) and pre-commit hooks so it does not happen again.

### 5. How do you make a Docker image more secure?

- Start from a small base image (alpine, distroless, or slim). Less software = fewer holes.
- Do not run as root. Add a `USER` line in the Dockerfile.
- Use multi-stage builds so build tools do not end up in the final image.
- Pin versions of base images and packages so builds are repeatable.
- Scan images for known vulnerabilities (Trivy, Grype) in the pipeline and block bad ones.
- Never copy secrets or `.env` files into the image.

### 6. How does HTTPS / TLS work, in simple terms?

- The server shows a certificate, signed by a trusted authority, to prove it really is that website.
- Browser and server agree on a shared key (using public/private key math) without anyone in between learning it.
- All traffic after that is encrypted with that key.
- It protects data while it travels (in transit). It does not protect data sitting on the server (at rest) or a server that is already hacked.
- Bonus: certificates expire. Automate renewal with Let's Encrypt or cert-manager.

### 7. How would you harden a fresh Linux server?

- Update all packages, and keep updating them (unattended-upgrades).
- Create a normal user with sudo. Do not work as root.
- SSH: keys only, disable password login, disable root login.
- Firewall: allow only the ports you need (ufw, firewalld, or security groups). Default deny.
- Install fail2ban to block repeated login attempts.
- Remove or stop services you do not use. Every open port is a risk.
- Changing the SSH port is optional. It cuts log noise but is not real security.

### 8. What is the difference between a security group and a NACL in AWS?

- Security group: firewall attached to an instance. Stateful: if you allow traffic in, the reply is automatically allowed out. Allow rules only.
- NACL: firewall attached to a subnet. Stateless: you must allow both inbound and outbound. Has allow and deny rules.
- Day to day you mostly use security groups. NACLs are for subnet-wide rules, like blocking a specific IP range.
- Common mistake: opening port 22 or a database port to 0.0.0.0/0.

### 9. What is RBAC in Kubernetes?

- Role-Based Access Control. It decides who can do what inside the cluster.
- Role / ClusterRole: a list of allowed actions (get, list, create, delete) on resources (pods, secrets). Role is for one namespace, ClusterRole is cluster-wide.
- RoleBinding / ClusterRoleBinding: connects a Role to a user, group, or service account.
- Apply least privilege: a deploy pipeline should update Deployments in its namespace, not read Secrets everywhere.
- Check with: `kubectl auth can-i delete pods --as=some-user`

### 10. What is "shift-left" security / DevSecOps?

- Move security checks to the start of the pipeline instead of an audit at the end. Problems found early are cheaper to fix.
- Typical checks in CI: secret scanning (gitleaks), dependency scanning (npm audit, Dependabot), image scanning (Trivy), IaC scanning (tfsec, Checkov).
- Fail the build on high/critical findings, warn on the rest.
- Security becomes part of everyone's job, not a separate team that says no at the end.
