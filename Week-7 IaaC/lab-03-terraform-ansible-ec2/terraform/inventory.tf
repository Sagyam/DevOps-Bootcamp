# ---------------------------------------------------------------------------
# THE HANDOFF. Terraform knows the IP; Ansible needs the IP. So Terraform
# renders the Ansible inventory file. No copy-pasting IPs from the console.
# ---------------------------------------------------------------------------

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    public_ip  = aws_eip.web.public_ip
    public_dns = aws_eip.web.public_dns
  })
}
