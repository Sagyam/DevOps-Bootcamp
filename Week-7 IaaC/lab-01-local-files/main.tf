# ---------------------------------------------------------------------------
# STEP 1: The simplest possible resource -- a file.
# Resource address = TYPE.NAME  ->  local_file.hello
# ---------------------------------------------------------------------------
resource "local_file" "hello" {
  filename = "${path.module}/output/hello.txt"
  content  = "Hello from Terraform! This file is MANAGED. Do not edit by hand (seriously, try it later)."
}

# ---------------------------------------------------------------------------
# STEP 2: Resources can depend on each other.
# random_pet generates a name; the file below REFERENCES it, so Terraform
# builds a dependency graph: random_pet first, then the file.
# ---------------------------------------------------------------------------
resource "random_pet" "server_name" {
  length    = 2
  separator = "-"
}

resource "local_file" "server_config" {
  filename = "${path.module}/output/server-config.ini"
  content  = templatefile("${path.module}/templates/server-config.tftpl", {
    shop_name   = var.shop_name
    server_name = random_pet.server_name.id
  })
}

# ---------------------------------------------------------------------------
# STEP 3: One block, many resources -- for_each.
# Terraform tracks each as local_file.student_welcome["asha"], etc.
# ---------------------------------------------------------------------------
resource "local_file" "student_welcome" {
  for_each = var.students

  filename = "${path.module}/output/students/${each.key}.txt"
  content  = "Welcome to ${var.shop_name}, ${each.key}! Your files are now infrastructure."
}
