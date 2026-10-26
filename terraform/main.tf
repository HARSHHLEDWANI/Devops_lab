terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }
}

resource "local_file" "payment_env" {
  filename = "${path.module}/payment.env"
  content  = "URL=http://localhost:30091\n"
}
