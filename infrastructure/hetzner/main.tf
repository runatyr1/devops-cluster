provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "k8s_node" {
  name        = "k8s-master"
  image       = "debian-12"
  server_type = "cx22" 
  location    = "fsn1" # Rotate between fsn1, nbg1, hel1
  ssh_keys    = [hcloud_ssh_key.default.id]

  labels = {
    environment = "learning"
    managed_by  = "terraform"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false # Disable IPv6 if not needed
  }

  # Wait for SSH to be available
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = file("${path.module}/../keys/hetzner-k8s")
    }
  }
}

resource "hcloud_ssh_key" "default" {
  name       = "hetzner-k8s"
  public_key = file("${path.module}/../keys/hetzner-k8s.pub")
}

output "k8s_node_ip" {
  value       = hcloud_server.k8s_node.ipv4_address
  description = "Public IP of the k8s node"
}

# Output SSH command for easy access
output "ssh_command" {
  value       = "ssh -i ${path.module}/../keys/hetzner-k8s root@${hcloud_server.k8s_node.ipv4_address}"
  description = "SSH command to connect to the server"
}