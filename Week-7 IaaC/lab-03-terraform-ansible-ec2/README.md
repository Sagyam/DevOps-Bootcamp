# Lab 03 — Terraform + Ansible: Provision, Then Configure

The finale. Terraform builds a production-shaped network and an EC2 instance on AWS;
Ansible then turns that blank Ubuntu box into a hardened HTTPS web server speaking
HTTP/3. The two tools meet at exactly one point: **Terraform writes Ansible's
inventory file.**

```
terraform apply                          ansible-playbook playbook.yml
┌──────────────────────────┐             ┌──────────────────────────────┐
│ VPC 10.0.0.0/16          │             │ apt update + dist-upgrade    │
│ ├─ Subnet 10.0.1.0/24    │             │ UFW: 22, 80, 443/tcp+udp     │
│ ├─ Internet Gateway      │  writes     │ self-signed TLS cert         │
│ ├─ Route table → IGW     │ ─────────▶  │ nginx (mainline, has QUIC)   │
│ ├─ Security group        │ inventory   │ h1.1 + h2 + h3 site config   │
│ ├─ Keypair → .pem file   │   .ini      │ custom 401/403/404/50x pages │
│ └─ EC2 + Elastic IP      │             │ copy HTML from your laptop   │
└──────────────────────────┘             └──────────────────────────────┘
```

## Prerequisites

```bash
aws sts get-caller-identity        # credentials working?
ansible --version                  # >= 2.15
cd ansible && ansible-galaxy collection install -r requirements.yml && cd ..
```

Cost note: t3.micro in ap-south-1 is a few cents/hour (free-tier eligible on new
accounts). **Destroy when done** — an Elastic IP also bills hourly once the instance
it's attached to is stopped or gone.

---

## Part A — Terraform (provision)

```bash
cd terraform
terraform init
terraform plan     # read it! ~12 resources; find the UDP 443 ingress rule and ask yourself why it exists
terraform apply
```

Optional but recommended — lock SSH to your own IP:

```bash
terraform apply -var="ssh_ingress_cidr=$(curl -s ifconfig.me)/32"
```

When it finishes, look at what Terraform wrote **locally**:

```bash
cat ../ansible/inventory.ini        # your server's IP, rendered by templatefile()
ls -l ../ansible/ssh/lab_key.pem    # private key, mode 0400
```

This is the handoff. Terraform resources aren't only cloud things — `local_file` from
Lab 01 is doing the glue work here.

Sanity check (give the instance ~60s to boot):

```bash
ssh -i ../ansible/ssh/lab_key.pem ubuntu@$(terraform output -raw public_ip) 'echo it lives'
```

### Guided tour of the .tf files (10 min, instructor-led)

- `vpc.tf` — why "public subnet" is just a route table pointing at an IGW
- `security.tf` — stateful firewall; the four ingress rules; **UDP 443 for QUIC**
- `ec2.tf` — AMI data source (never hardcode AMI IDs), Elastic IP vs auto-assigned IP
- `keypair.tf` + `inventory.tf` — Terraform feeding Ansible

## Part B — Ansible (configure)

```bash
cd ../ansible
ansible web -m ping                 # green? the inventory + key work
ansible-playbook playbook.yml
```

While it runs, follow along in `playbook.yml` — every section is commented. Highlights
worth calling out to students:

- **UFW ordering**: SSH is allowed *before* the firewall is enabled. Flip that order and
  you brick your own access. (The brief said "only 80 and 443" — we keep 22 because
  Ansible needs it; the security group already controls who can reach it. In prod: bastion.)
- **Why nginx.org packages**: Ubuntu 24.04's nginx (1.24) has no HTTP/3. Mainline does.
  The playbook literally asserts `http_v3_module` is compiled in and fails if not.
- **Idempotency**: run the playbook a second time → `changed=0`. Ansible's "No changes."

## Part C — Verify

```bash
IP=$(cd ../terraform && terraform output -raw public_ip)

curl -I  http://$IP                 # 301 -> https
curl -kI https://$IP                # 200, look for: alt-svc: h3=":443"
curl -k  https://$IP/vault -i       # 401 + custom page
curl -k  https://$IP/admin -i       # 403 + custom page
curl -k  https://$IP/nope  -i       # 404 + custom page
curl -k  https://$IP/teapot         # 418, obviously
```

`-k` skips cert verification — required because our cert is self-signed.

### Testing HTTP/3

Stock curl isn't built with HTTP/3. Two options:

```bash
# Option 1: docker image with h3-enabled curl
docker run --rm badouralix/curl-http3 curl -kI --http3-only https://$IP/

# Option 2: from the instance itself (nginx.org curl there won't have h3 either;
# easiest is option 1, or check the access log protocol field)
```

Then open `https://$IP` in a browser (click through the cert warning). The page
JavaScript shows which protocol delivered it — and it will say **h2, not h3**. That's
not a bug; it's the lesson:

> **Graceful fallback in action.** Browsers only upgrade to HTTP/3 after seeing the
> `Alt-Svc` header *and* only for certificates they trust. Self-signed cert → browser
> ignores Alt-Svc → stays on TCP/h2, and everything still works. Swap in a real cert
> (Let's Encrypt + a domain) and the same config serves h3 to browsers. The fallback
> path is the default path.

Also try: block UDP 443 in the security group, re-test with the docker curl — h3 dies,
h2 keeps serving. Fallback again.

## Part D — Destroy

```bash
cd ../terraform
terraform destroy
```

Note the plan includes the local files too — inventory and .pem are destroyed with
everything else. Terraform giveth, Terraform taketh away.

## Checkpoint questions

1. Both the security group *and* UFW allow 80/443. Why run two firewalls? What does
   each protect against that the other doesn't?
2. Why does HTTP/3 need a UDP ingress rule when HTTPS "is port 443"?
3. What would happen if you ran `ansible-playbook` before `terraform apply`?
4. The instance's auto-assigned public IP vs. the Elastic IP — which one is in your
   inventory, and why does it matter after a stop/start?
5. Could Terraform have done Ansible's job with `user_data`? Where's the line between
   provisioning and configuration? (There isn't a clean one — discuss.)

## Stretch goals

- Point a real domain at the EIP and replace the self-signed cert with Let's Encrypt
  (certbot) — then watch your browser actually negotiate h3.
- Add a second instance with `count = 2` and make the inventory template loop over both.
- Move the Ansible tasks into roles (`common`, `firewall`, `tls`, `nginx`, `site`).
