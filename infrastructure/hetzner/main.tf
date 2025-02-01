provider "hcloud" {
  token = var.hcloud_token
}

# Network resources
resource "hcloud_network" "k8s_network" {
  name     = "k8s-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k8s_subnet" {
  network_id   = hcloud_network.k8s_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Server resource
resource "hcloud_server" "k8s_node" {
  name        = "k8s-master"
  image       = "debian-12"
  server_type = "cx22" 
  location    = "hel1" # Rotate between fsn1, nbg1, hel1
  ssh_keys    = [hcloud_ssh_key.default.id]

  labels = {
    environment = "learning"
    managed_by  = "terraform"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false # Disable IPv6 if not needed
  }

  network {
    network_id = hcloud_network.k8s_network.id
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

resource "local_file" "metallb_config" {
  content = templatefile("../../kubernetes/base/templates/metal-lb-config.tpl", {
    public_ip = hcloud_server.k8s_node.ipv4_address
  })
  filename = "../../kubernetes/base/manifests/metal-lb-config.yaml"
}

# SSH key resource
resource "hcloud_ssh_key" "default" {
  name       = "hetzner-k8s"
  public_key = file("${path.module}/../keys/hetzner-k8s.pub")
}



# CSI Driver config
resource "local_file" "csi_driver" {
  content = templatefile("../../kubernetes/base/templates/csi-driver.yaml.tpl", {
    hcloud_token = var.hcloud_token
  })
  filename = "../../kubernetes/base/manifests/hetzner-csi.yaml"
}



# Outputs
output "k8s_node_ip" {
  value       = hcloud_server.k8s_node.ipv4_address
  description = "Public IP of the k8s node"
}

output "k8s_node_private_ip" {
  value       = tolist(hcloud_server.k8s_node.network)[0].ip
  description = "Private IP of the k8s node"
}

output "ssh_command" {
  value       = "ssh -i ${path.module}/../keys/hetzner-k8s root@${hcloud_server.k8s_node.ipv4_address}"
  description = "SSH command to connect to the server"
}