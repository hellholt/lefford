terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 1.1.4"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.13"
    }
  }
  required_version = ">= 1.3.8"
}

variable "onepassword_vault_id" {
  type = string
}

variable "onepassword_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_api_username" {
  type = string
}

variable "proxmox_api_password" {
  type      = string
  sensitive = true
}

variable "client_ssh_pub_key" {
  type      = string
  sensitive = false
}

provider "onepassword" {
  url   = "https://1password-connect-api.lefford.hellholt.net"
  token = var.onepassword_api_token
}

provider "proxmox" {
  pm_user     = var.proxmox_api_username
  pm_password = var.proxmox_api_password
  pm_api_url  = "https://pve.lefford.hellholt.net/api2/json"
  pm_debug    = true

}

data "external" "ansible_inventory" {
  program = ["python3", "${path.module}/scripts/collect_ansible_inventory.py"]
  query = {
    inventory_file = "${path.module}/../ansible/inventory/hosts"
    host_vars_dir  = "${path.module}/../ansible/inventory/host_vars/"
    output_file    = "${path.module}/ansible_inventory.tmp.yaml"
  }
}

locals {
  ansible_inventory = jsondecode(data.external.ansible_inventory.result.result)
  pve_lxc_hosts     = local.ansible_inventory.all.children.pve_lxc.hosts
  pve_lxc_host_names = toset(keys(local.pve_lxc_hosts))
  // pve_k8s_cp_hosts = [yamldecode(data.yaml_decode.merged_inventory).all.children.pve_k8s.children.pve_k8s_cp.hosts]
  // pve_k8s_worker_hosts = [yamldecode(data.yaml_decode.merged_inventory).all.children.pve_k8s.children.pve_k8s_workers.hosts]
  // pve_kvm_hosts = [yamldecode(data.yaml_decode.merged_inventory).all.children.pve_kvm.hosts]
  // host_data = yamldecode(data.yaml_decode.merged_inventory).all.children.pve_hosts.hosts
}

resource "proxmox_lxc" "lxc_hosts" {
  for_each        = toset(local.pve_lxc_host_names)
  target_node     = "lefford"
  hostname        = each.key
  ostemplate      = local.pve_lxc_hosts[each.key].pve_lxc_template
  unprivileged    = local.pve_lxc_hosts[each.key].pve_option_unprivileged
  onboot          = local.pve_lxc_hosts[each.key].pve_option_onboot
  start           = local.pve_lxc_hosts[each.key].pve_option_start
  swap            = local.pve_lxc_hosts[each.key].pve_swap
  memory          = local.pve_lxc_hosts[each.key].pve_memory
  password        = var.proxmox_api_password
  ssh_public_keys = <<-EOT
    ${var.client_ssh_pub_key}
  EOT
  vmid            = local.pve_lxc_hosts[each.key].pve_vm_id

  features {
    fuse    = true
    nesting = true
    mount   = "nfs;cifs"
  }

  rootfs {
    storage = "leo"
    size    = local.pve_lxc_hosts[each.key].pve_rootfs_size
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = local.pve_lxc_hosts[each.key].pve_mac_address
    ip     = "dhcp"
    ip6    = "auto"
  }

}

