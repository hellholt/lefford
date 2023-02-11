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

resource "proxmox_lxc" "ambrose" {
  target_node     = "lefford"
  hostname        = "ambrose"
  ostemplate      = "local:vztmpl/ubuntu-22.10-standard_22.10-1_amd64.tar.zst"
  unprivileged    = false
  onboot          = true
  start           = true
  swap            = 512
  password        = var.proxmox_api_password
  ssh_public_keys = <<-EOT
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDl4yAh6KtLO0E6/faWBt3LxMCVMXXooGqUBm+63XI6ckHtt8jEBh1XgzMYLWqpoCpt69uk131HUrzFjXl1kDJ8Ttqx/CvakJkMv/iJ2Ofzjx0NVHr46/tcDvpDyDYMcY6kj1ZjvfJfuh1OSdyeS/VfXsyIIj3GlnxiCugyg+ocHXjMqyCerxgDJGbXck5aip7sAcHvKIAAYGAlt6WN6398SbFmdKg3Y0H+AxWm/4HvKuecC1oRvBVtXfQoASWKkaEuiNOWT5WREazxAAJqWnuzKTk5nWPjiYuC4pvUPPyfncoRBrutodTJoZ5QYuKfPoHgFz6s0lJKi2qTXm4FSJyQ7ZyKLnFw1Rfj2EhG7TytadcvqbbPw7TVlhKFjnebYC8A4zgBCRXlZLfQBSjbrh0WOPh5Rw1pqdX0jLTYl3rqnSta1EubLmzNuvBypO6I69tdS0OUr6DTYomZha95A/Qb1vZWrBXABPrzs4x8t6ItnDAoIchaxuljFpCqasRnf7C7IaitjOFWAproMtDlqg+1Lyu5gAfK3b3S1V8T9y2Xp2oQ1kcWEb1fkk0o9KFN9g3xDWUzSHWk/vLZVGzTBEceYqMTYYqhNjWje8e1m9HEEQXi+QNTWJx1FuZmjAHPeALb3JgDOFZoJt0gD4P4QgeKYpkoAvIVkOjXXKHTgiytQ== nathan@greyjoy
  EOT

  features {
    fuse    = true
    nesting = true
    mount   = "nfs;cifs"
  }

  rootfs {
    storage = "leo"
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "de:fe:c8:03:00:64"
    ip     = "dhcp"
    ip6    = "auto"
  }
}

