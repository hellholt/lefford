import os
import json
import sys
import yaml

INVENTORY_FILE = "/Users/nathan/Projects/lefford/ansible/inventory/hosts"
HOST_VARS_DIR = "/Users/nathan/Projects/lefford/ansible/inventory/host_vars/"
OUTPUT_FILE = "/Users/nathan/Projects/lefford/terraform/ansible_inventory.tmp.yaml"

def check_dict_path(dict, *indices):
  sentinel = object()
  for index in indices:
    dict = dict.get(index, sentinel)
    if dict is sentinel:
      return False
  return True

def load_inventory(inventory_file):
  with open(inventory_file, 'r') as f:
    inventory = yaml.safe_load(f)
  return inventory

def load_host_vars(host_vars_dir, host):
  host_vars_file = os.path.join(host_vars_dir, host + ".yaml")
  if os.path.exists(host_vars_file):
    with open(host_vars_file, 'r') as f:
      host_vars = yaml.safe_load(f)
  else:
    host_vars = {}
  return host_vars

def merge_inventory_and_host_vars(inventory, host_vars_dir):
  pve_hosts = inventory['all']['children']['pve_hosts']
  for group_vars in pve_hosts.values():
    group_hosts = group_vars.keys()
    for host in group_hosts:
      host_vars = load_host_vars(host_vars_dir, host)
      if host_vars:
        inventory['all']['children']['pve_hosts']['hosts'][host] = host_vars
        if check_dict_path(inventory, 'all', 'children', 'pve_lxc', 'hosts', host):
          inventory['all']['children']['pve_lxc']['hosts'][host] = host_vars
        if check_dict_path(inventory, 'all', 'children', 'pve_k8s', 'children', 'pve_k8s_cp', 'hosts', host):
          inventory['all']['children']['pve_k8s']['children']['pve_k8s_cp']['hosts'][host] = host_vars
        if check_dict_path(inventory, 'all', 'children', 'pve_k8s', 'children', 'pve_k8s_workers', 'hosts', host):
          inventory['all']['children']['pve_k8s']['children']['pve_k8s_workers']['hosts'][host] = host_vars
        if check_dict_path(inventory, 'all', 'children', 'pve_kvm', 'hosts', host):
          inventory['all']['children']['pve_kvm']['hosts'][host] = host_vars
  return inventory

def write_merged_inventory(inventory, output_file):
  with open(output_file, 'w') as f:
    yaml.dump(inventory, f)
    sys.stdout.write(json.dumps({
      "result": json.dumps(inventory, indent=2),
    }))

if __name__ == "__main__":
  input_data = json.loads(sys.stdin.read())
  inventory = load_inventory(input_data['inventory_file'])
  inventory = merge_inventory_and_host_vars(inventory, input_data['host_vars_dir'])
  write_merged_inventory(inventory, input_data['output_file'])
  
