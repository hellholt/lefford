# ☀️ Lefford

![☀️ nathan@lefford:~](./images/prompt.png)

**Lefford** is a Dell R720XD server with 384GB RAM and a ~42TB RAIDZ2 volume running Proxmox.  It's also the core of my homelab, which is more broadly referred to as [Hellholt](https://github.com/hellholt/), after some substantial downsizing in early 2023.

Please feel free to read through these files; although they're not likely to be *directly* useful to you, they might help you with your own homelab :slightly_smiling_face:!

Infrastructure was initially managed through [Terraform](https://terraform.io/); I liked the idea of managing the infrastructure with Terraform and configuration with [Ansible](https://ansible.com/).  Alas, it was not to be; I did not find the Proxmox provider to be reliable under Terraform.  So ultimately, I find myself managing both through Ansible.

## Overview

- [**Hellholt**](https://github.com/hellholt/): The Homelab as a whole.
  - [**Lefford**](https://github.com/hellholt/lefford/): Lefford, my HCI server.
    - [**Karhold**](https://github.com/hellholt/karhold/): Karhold, a Kubernetes cluster running on LXC containers and managed via Argo CD.
    - [**Longtable**](https://github.com/hellholt/longtable/): Longtable, a Nomad cluster running on QEMU VMs.

