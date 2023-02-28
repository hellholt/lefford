terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.13"
    }
  }
  required_version = ">= 1.3.8"
}

# Proxmox host, just because I get tired of typing it.
variable "proxmox_host" {
  type = string
}

# API username for Lefford Proxmox VE server.
variable "proxmox_api_username" {
  type = string
}

# API password for Lefford Proxmox VE server.
variable "proxmox_api_password" {
  type      = string
  sensitive = true
}

# SSH username for Lefford Proxmox VE server.
variable "proxmox_ssh_username" {
  type = string
}

# SSH password for Lefford Proxmox VE server.
variable "proxmox_ssh_password" {
  type      = string
  sensitive = true
}

# SSH public key for client, uploaded to each host.
variable "client_ssh_pub_key" {
  type      = string
  sensitive = false
}

# Configure the Proxmox VE provider.
provider "proxmox" {
  pm_user     = var.proxmox_api_username
  pm_password = var.proxmox_api_password
  pm_api_url  = "https://pve.lefford.hellholt.net/api2/json"
  pm_debug    = true
}

# A Resource to force recreation of other resources.
resource "null_resource" "always_run" {
  triggers = {
    timestamp = "${timestamp()}"
  }
}

# Collect Ansible inventory data.
#
# This is a bit of a hack, but it works. The script collects the data from the
# Ansible inventory and writes it to a temporary file. The temporary file is
# then read by the data "external" resource and the data is passed to the
# Terraform local variables.
data "external" "ansible_inventory" {
  program = ["python3", "${path.module}/scripts/collect_ansible_inventory.py"]
  # The script expects the following arguments, which are passed in via stdin
  # as a JSON object.
  query = {
    inventory_file = "${path.module}/../ansible/inventory/hosts"
    host_vars_dir  = "${path.module}/../ansible/inventory/host_vars/"
    output_file    = "${path.module}/ansible_inventory.tmp.yaml"
  }
}

# Local variable definition.
locals {
  # Retrieve the merged Ansible inventory data.
  ansible_inventory = jsondecode(data.external.ansible_inventory.result.result)
  # All hosts
  pve_hosts = local.ansible_inventory.all.children.pve_hosts.hosts
  # LXC hosts
  pve_lxc_hosts      = local.ansible_inventory.all.children.pve_lxc.hosts
  pve_lxc_host_names = toset(keys(local.pve_lxc_hosts))
  # K8s control plane hosts
  pve_k8s_cp_hosts      = local.ansible_inventory.all.children.pve_k8s.children.pve_k8s_cp.hosts
  pve_k8s_cp_host_names = toset(keys(local.pve_k8s_cp_hosts))
  # K8s worker hosts
  pve_k8s_worker_hosts      = local.ansible_inventory.all.children.pve_k8s.children.pve_k8s_workers.hosts
  pve_k8s_worker_host_names = toset(keys(local.pve_k8s_worker_hosts))
  # Miscellaneous KVM hosts
  pve_kvm_hosts      = local.ansible_inventory.all.children.pve_kvm.hosts
  pve_kvm_host_names = toset(keys(local.pve_kvm_hosts))
}

# Create a local copy of the files for transfer to Proxmox.
resource "local_file" "pve_k8s_cp_cloud_init" {
  for_each = toset(local.pve_k8s_cp_host_names)
  # Replace the variables in the cloud-config template.
  content = templatefile("${path.module}/files/pve_k8s_cloud_init.cloud_config", {
    ssh_key  = var.client_ssh_pub_key
    hostname = each.key
    domain   = "${var.proxmox_host}.hellholt.net"
  })
  filename = "${path.module}/files/tmp/pve_k8s_cp_cloud_init__${each.key}.cfg"
  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
}

# Create a local copy of the files for transfer to Proxmox.
resource "local_file" "pve_k8s_worker_cloud_init" {
  for_each = toset(local.pve_k8s_worker_host_names)
  # Replace the variables in the cloud-config template.
  content = templatefile("${path.module}/files/pve_k8s_cloud_init.cloud_config", {
    ssh_key  = var.client_ssh_pub_key
    hostname = each.key
    domain   = "${var.proxmox_host}.hellholt.net"
  })
  filename = "${path.module}/files/tmp/pve_k8s_worker_cloud_init__${each.key}.cfg"
  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
}

# Transfer the file to the Proxmox Host.
resource "null_resource" "pve_k8s_cp_cloud_init" {
  for_each = toset(local.pve_k8s_cp_host_names)
  depends_on = [
    local_file.pve_k8s_cp_cloud_init
  ]
  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = var.proxmox_host
  }

  provisioner "file" {
    source      = local_file.pve_k8s_cp_cloud_init[each.key].filename
    destination = "/var/lib/vz/snippets/pve_k8s_cp_cloud_init--${each.key}.yml"
  }

  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
}

# Transfer the file to the Proxmox Host.
resource "null_resource" "pve_k8s_worker_cloud_init" {
  for_each = toset(local.pve_k8s_worker_host_names)
  depends_on = [
    local_file.pve_k8s_worker_cloud_init
  ]
  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = var.proxmox_host
  }

  provisioner "file" {
    source      = local_file.pve_k8s_worker_cloud_init[each.key].filename
    destination = "/var/lib/vz/snippets/pve_k8s_worker_cloud_init--${each.key}.yml"
  }

  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
}

# Create the K8s control plane hosts.
resource "proxmox_vm_qemu" "pve_k8s_cp_hosts" {
  for_each = toset(local.pve_k8s_cp_host_names)
  depends_on = [
    null_resource.pve_k8s_cp_cloud_init
  ]
  name                    = each.key
  target_node             = var.proxmox_host
  clone                   = "debian-cloudinit"
  os_type                 = "cloud-init"
  cicustom                = "user=local:snippets/pve_k8s_cp_cloud_init--${each.key}.yml"
  cloudinit_cdrom_storage = "leo"
  vmid                    = local.pve_hosts[each.key].pve_vm_id
  bios                    = "seabios"
  onboot                  = true
  agent                   = 1
  memory                  = local.pve_hosts[each.key].pve_memory
  cores                   = local.pve_hosts[each.key].pve_cores
  scsihw                  = "virtio-scsi-pci"
  network {
    model   = "virtio"
    macaddr = local.pve_hosts[each.key].pve_mac_address
    bridge  = "vmbr0"
  }
}

# Create the K8s worker VMs.
resource "proxmox_vm_qemu" "pve_k8s_worker_hosts" {
  for_each = toset(local.pve_k8s_worker_host_names)
  depends_on = [
    null_resource.pve_k8s_worker_cloud_init,
    proxmox_vm_qemu.pve_k8s_cp_hosts
  ]
  name                    = each.key
  target_node             = var.proxmox_host
  clone                   = "debian-cloudinit"
  os_type                 = "cloud-init"
  cicustom                = "user=local:snippets/pve_k8s_worker_cloud_init--${each.key}.yml"
  cloudinit_cdrom_storage = "leo"
  vmid                    = local.pve_hosts[each.key].pve_vm_id
  bios                    = "seabios"
  onboot                  = true
  agent                   = 1
  memory                  = local.pve_hosts[each.key].pve_memory
  cores                   = local.pve_hosts[each.key].pve_cores
  scsihw                  = "virtio-scsi-pci"
  network {
    model   = "virtio"
    macaddr = local.pve_hosts[each.key].pve_mac_address
    bridge  = "vmbr0"
  }
}

# Define the LXC hosts using the local variables.
resource "proxmox_lxc" "lxc_hosts" {
  for_each        = toset(local.pve_lxc_host_names)
  target_node     = var.proxmox_host
  hostname        = each.key
  ostemplate      = local.pve_hosts[each.key].pve_lxc_template
  unprivileged    = local.pve_hosts[each.key].pve_option_unprivileged
  onboot          = local.pve_hosts[each.key].pve_option_onboot
  start           = local.pve_hosts[each.key].pve_option_start
  swap            = local.pve_hosts[each.key].pve_swap
  memory          = local.pve_hosts[each.key].pve_memory
  password        = var.proxmox_api_password
  ssh_public_keys = <<-EOT
    ${var.client_ssh_pub_key}
  EOT
  vmid            = local.pve_hosts[each.key].pve_vm_id

  features {
    fuse    = true
    nesting = true
    mount   = "nfs;cifs"
  }

  rootfs {
    storage = "leo"
    size    = local.pve_hosts[each.key].pve_rootfs_size
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = local.pve_hosts[each.key].pve_mac_address
    ip     = "dhcp"
    ip6    = "auto"
  }

}
