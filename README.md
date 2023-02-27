# ☀️ Lefford

![☀️ nathan@lefford:~](./images/prompt.png)

**Lefford** is a Dell R720XD server with 384GB RAM and a ~42TB RAIDZ2 volume running Proxmox.  It's also the core of my homelab, which is more broadly referred to as [Hellholt](https://github.com/hellholt/), after some substantial downsizing in early 2023.

## Infrastructure

Infrastructure is managed using [Terraform](https://www.terraform.io).  See [`terraform`](./terraform/README.md) for details.

### Overview

- [**Hellholt**](https://github.com/hellholt/): The Homelab as a whole.
  - [**Lefford**](https://github.com/hellholt/lefford/): Lefford, my HCI server.
    - [**Karhold**](https://github.com/hellholt/karhold/): Karhold, a Kubernetes cluster running on LXC containers and managed via Argo CD.
    - [**Longtable**](https://github.com/hellholt/longtable/): Longtable, a Nomad cluster running on QEMU VMs.

## Configuration

Configuration is managed using [Ansible](https://www.ansible.com).  See [`ansible`](./ansible/README.md) for details.

 Various systems, including some not managed via Terraform (such as my laptop, some Raspberry Pis, etc) use various elements of configuration that can be managed here.

