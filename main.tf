  # -------------------------
  # Random suffix for SSH key
  # -------------------------
  resource "random_id" "suffix" {
    byte_length = 3
  }

  # -------------------------
  # Get Ubuntu 22.04 image data
  # -------------------------
  data "hcloud_image" "ubuntu" {
    name = "ubuntu-22.04"
    most_recent = true
    with_selector = "architecture==x86"
  }

  # -------------------------
  # Generate SSH key
  # -------------------------
  resource "tls_private_key" "default" {
    algorithm = "RSA"
    rsa_bits  = 4096
  }

  # -------------------------
  # Add SSH key to Hetzner
  # -------------------------
  resource "hcloud_ssh_key" "default" {
    name       = "terraform-key-${random_id.suffix.hex}"
    public_key = tls_private_key.default.public_key_openssh
  }

  # -------------------------
  # Master node
  # -------------------------
  resource "hcloud_server" "k3s_master" {
    name        = "${var.cluster_name}-master"
    image       = data.hcloud_image.ubuntu.id
    server_type = "cpx11"
    location    = "fsn1"
    ssh_keys    = [hcloud_ssh_key.default.id]
  }

  # -------------------------
  # Worker nodes
  # -------------------------
  resource "hcloud_server" "k3s_worker" {
    count       = var.worker_count # Add count for multiple workers
    name        = "${var.cluster_name}-worker-${count.index + 1}"
    image       = data.hcloud_image.ubuntu.id
    server_type = "cpx11"
    location    = "fsn1"
    ssh_keys    = [hcloud_ssh_key.default.id]
  }

  # -------------------------
  # Write private key to file
  # -------------------------
  resource "local_file" "private_key_file" {
    filename        = "${path.module}/private_key.pem"
    content         = tls_private_key.default.private_key_pem
    file_permission = "0600"
  }

  # -------------------------
  # Generate Ansible inventory
  # -------------------------
  resource "local_file" "ansible_inventory" {
    filename        = "${path.module}/ansible/inventories/inventory.ini"
    file_permission = "0640"

    content = <<-EOF
  [k3s_master]
  manager1 ansible_host=${hcloud_server.k3s_master.ipv4_address} ansible_user=root ansible_ssh_private_key_file=./private_key.pem

  [k3s_workers]
  %{~ for i, worker in hcloud_server.k3s_worker ~}
  worker${i + 1} ansible_host=${worker.ipv4_address} ansible_user=root ansible_ssh_private_key_file=./private_key.pem
  %{~ endfor ~}

  [all:vars]
  ansible_python_interpreter=/usr/bin/python3
  ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOF
  }

  # -------------------------
  # Run Ansible playbooks automatically
  # -------------------------
  resource "null_resource" "run_ansible" {
    depends_on = [
      hcloud_server.k3s_master,
      hcloud_server.k3s_worker,
      local_file.ansible_inventory,
      local_file.private_key_file
    ]
    provisioner "local-exec" {
      command = <<EOT
        echo "Waiting for SSH to become available..."
        for i in {1..10}; do
          nc -zv ${hcloud_server.k3s_master.ipv4_address} 22 && break
          sleep 10
        done
        ansible-playbook -i ${local_file.ansible_inventory.filename} playbooks/k3s.yml
        ansible-playbook -i ${local_file.ansible_inventory.filename} playbooks/deploy.yml
      EOT
    }
  }

  # -------------------------
  # Outputs
  # -------------------------
  output "master_ip" {
    description = "IP address of the master node"
    value       = hcloud_server.k3s_master.ipv4_address
  }

  output "worker_ips" {
    description = "IP addresses of worker nodes"
    value       = hcloud_server.k3s_worker[*].ipv4_address
  }

  output "private_key_file" {
    description = "Path to the generated private key file"
    value       = local_file.private_key_file.filename
    sensitive   = true
  }

  output "ssh_key_name" {
    description = "Name of the SSH key in Hetzner Cloud"
    value       = hcloud_ssh_key.default.name
  }

  output "ansible_inventory_file" {
    description = "Path to the generated Ansible inventory file"
    value       = local_file.ansible_inventory.filename
  }