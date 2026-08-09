# ---------------------------------------------------------------------------
# Terraform generates the SSH keypair and saves the private key to disk --
# straight into the ansible/ directory. This is Lab 01's local_file trick,
# now doing real work: it is how Terraform hands credentials to Ansible.
# ---------------------------------------------------------------------------

resource "tls_private_key" "lab" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "lab" {
  key_name   = "tf-ansible-lab-key"
  public_key = tls_private_key.lab.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  filename        = "${path.module}/../ansible/ssh/lab_key.pem"
  content         = tls_private_key.lab.private_key_openssh
  file_permission = "0400" # ssh refuses keys that are group/world readable
}
