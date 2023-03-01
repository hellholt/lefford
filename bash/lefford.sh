#!/usr/bin/env bash

ansible_path="${LEFFORD_ANSIBLE_PATH:-${HOME}/Projects/lefford/ansible}";

# Edit the vault.
function lefford:edit_vault() {
  pushd "${ansible_path}" > /dev/null;
  ansible-vault edit ./inventory/group_vars/all/vault;
  popd > /dev/null;
}

# Run a specified Ansible playbook.
function lefford:ansible_playbook() {
  : "${2?"Usage: ${FUNCNAME[0]} <PLAYBOOK>"}";
  local playbook_expression="${1}";
  pushd "${ansible_path}" > /dev/null;
  ansible-playbook "${playbook_expression}";
  popd > /dev/null;
}

# Run a specified Ansible role.
function lefford:ansible_role() {
  : "${2?"Usage: ${FUNCNAME[0]} <HOSTNAME|GROUP> <ROLE> <TASKFILE>"}";
  local host_expression="${1}";
  local role_name="${2}";
  pushd "${ansible_path}" > /dev/null;
  ansible-playbook ${@:3} /dev/stdin <<END
---
- hosts: $host_expression
  roles:
    - '$role_name'
END
  popd > /dev/null;
}

# Run a specified Ansible task.
function lefford:ansible_task() {
  : "${3?"Usage: ${FUNCNAME[0]} <HOSTNAME|GROUP> <ROLE> <TASKFILE>"}";
  local host_expression="${1}";
  local role_name="${2}";
  local task_file="${3}";
  pushd "${ansible_path}" > /dev/null;
  ansible-playbook ${@:4} /dev/stdin <<END
---
- hosts: $host_expression
  remote_user: 'root'
  tasks:

  - name: 'Execute $role_name:$task_file'
    ansible.builtin.include_role:
      name: '$role_name'
      tasks_from: '$task_file'
END
  popd > /dev/null;
}

# Perform an operation on the Proxmox VE node.
function lefford:pve_node() {
  : "${2?"Usage: ${FUNCNAME[0]} <COMMAND> <HOSTNAME|GROUP>"}";
  local host_expression="${1}";
  local subcommand="${2}";
  local args="${@:3}";
  # If we need to perform an operation on the node, we can assume that it is
  # already provisioned.
  ANSIBLE_GATHERING='implicit' lefford:ansible_task \
    'lefford' \
    'lefford.pve_node' \
    "${subcommand}.yaml" \
    "${args}";
}

# Perform an operation on an LXC container.
function lefford:pve_lxc() {
  : "${2?"Usage: ${FUNCNAME[0]} <COMMAND> <HOSTNAME|GROUP>"}";
  local host_expression="${1}";
  local subcommand="${2}";
  local args="${@:3}";
  # We need to use explicit gathering for LXC containers because they are not
  # always provisioned yet.
  ANSIBLE_GATHERING='explicit' lefford:ansible_task \
    "${host_expression}" \
    'lefford.pve_lxc' \
    "${subcommand}.yaml" \
    "${args}";
}

# Perform setup operations on a Proxmox VE LXC container.
function lefford:setup_host() {
  : "${1?"Usage: ${FUNCNAME[0]} <HOSTNAME|GROUP>"}";
  local host_expression="${1}";
  local operation="${2}";
  local args="${@:3}";
  pushd "${ansible_path}" > /dev/null;
  # Use root user for setup operations.
  lefford:ansible_role \
    "${host_expression}" \
    'lefford.pve_lxc' \
    "${operation}.yaml" \
    -e 'ansible_user=root' \
    "${args}";
  popd > /dev/null;
}

# Apply a setup group to a host.
function lefford:apply_setup_group() {
  : "${2?"Usage: ${FUNCNAME[0]} <HOSTNAME|GROUP> <SETUP_GROUP>"}";
  local host_expression="${1}";
  local setup_group="${2}";
  local args="${@:3}";
  # We can use implicit gathering for setup groups because they are always
  # provisioned at this point. We should use the root user for setup.
  ANSIBLE_GATHERING='implicit' lefford:ansible_task \
    "${host_expression}" \
    'lefford.setup_host' \
    "setup_groups/${setup_group}.yaml" \
    "${args}" \
    --become;
}

# Perform an operation on the Kubernetes cluster.
function lefford:k8s_cluster() {
  : "${2?"Usage: ${FUNCNAME[0]} <COMMAND> <HOSTNAME|GROUP>"}";
  local subcommand="${1}";
  local args="${@:2}";
  # We don't know if the cluster is provisioned yet, so we need to use explicit
  # gathering.
  ANSIBLE_GATHERING='explicit' \
    lefford:ansible_task \
    'pve_k8s' \
    'lefford.kubernetes' \
    "${subcommand}.yaml" \
    "${args}";
}

# Show usage information.
function lefford:usage() {
  local subcommand_width='18';
  local subcommand_column="%${subcommand_width}s    %s\n";
  echo 'Usage: lefford <subcommand> [arguments...]';
  echo '';
  echo 'General subcommands: ';
  printf "${subcommand_column}" 'usage' 'Show usage information.';
  printf "${subcommand_column}" 'ansible_task' 'Run a specified Ansible task.';
  printf "${subcommand_column}" 'edit_vault' 'Edit the vault.';
  printf "${subcommand_column}" 'autocomplete' 'Output autocomplete information.';
  printf "${subcommand_column}" 'pve_node:setup' 'Run setup on the Proxmox VE node.';
  echo '';
  echo 'Proxmox VE LXC container subcommands:';
  printf "${subcommand_column}" 'pve_lxc:create' 'Create the container(s).';
  printf "${subcommand_column}" 'pve_lxc:destroy' 'Destroy the container(s).';
  printf "${subcommand_column}" 'pve_lxc:stop' 'Stop the container(s).';
  printf "${subcommand_column}" 'pve_lxc:start' 'Start the container(s).';
  printf "${subcommand_column}" 'pve_lxc:restart' 'Restart the container(s).';
  printf "${subcommand_column}" 'pve_lxc:recreate' 'Destroy and recreate the container(s).';
  printf "${subcommand_column}" 'pve_lxc:setup' 'Setup the container(s).';
  echo '';
  echo 'Kubernetes cluster subcommands:';
  printf "${subcommand_column}" 'create_cluster' 'Create cluster (but do not deploy tasks).';
  printf "${subcommand_column}" 'recreate_cluster' 'Destroy and rereate the cluster (but do not deploy tasks).';
  printf "${subcommand_column}" 'destroy_cluster' 'Destroy the cluster.';
  printf "${subcommand_column}" 'reset_cluster' 'Reset the cluster and deploy tasks.';
  printf "${subcommand_column}" 'setup_cluster' 'Setup the cluster and deploy tasks.';
  printf "${subcommand_column}" 'redeploy_cluster' 'Deploy/redeploy tasks on the clustter.';
  echo '';
}

# Retrieve list of roles.
function lefford:list_roles() {
  for i in "${ansible_path}/roles/"lefford.*; do
    echo "${i#*\.}";
  done;
}

general_subcommands=(
  'usage'
  'ansible_task'
  'edit_vault'
  'autocomplete'
)

# Roles.
IFS=$'\n' read -d '' -r -a discovered_subcommands < <(lefford:list_roles)

# Valid subcommands of lefford:k8s_cluster.
k8s_cluster_subcommands=(
  'create_cluster'
  'recreate_cluster'
  'destroy_cluster'
  'reset_cluster'
  'setup_cluster'
  'redeploy_cluster'
)

# Print autocomplete script.
function lefford:autocomplete() {
  local old_ifs="${IFS}";
  IFS=\ ;
  local all_subcommands=(
    "$(echo "${general_subcommands[*]}")"
    "$(echo "${discovered_subcommands[*]}")"
    "$(echo "${k8s_cluster_subcommands[*]}")"
  )
  local subcommands_string="$(echo "${all_subcommands[*]}")";
  echo complete -W "'"${subcommands_string}"'" lefford;
  IFS="${old_ifs}";
}

# Primary function.
function lefford() {
  : "${1?"Usage: ${FUNCNAME[0]} <SUBCOMMAND> [ARGUMENTS] ..."}";
  local subcommand="${1}";
  export OBJC_DISABLE_INITIALIZE_FORK_SAFETY='YES';
  export K8S_AUTH_KUBECONFIG='~/.kube/config';
  shift;
  if type "lefford:${subcommand%:*}" > /dev/null 2>&1; then
    "lefford:${subcommand%:*}" "${1}" "${subcommand#*:}" "${@:2}";
  elif [[ " ${discovered_subcommands[*]} " =~ " ${subcommand%:*} " ]]; then
    lefford:ansible_task "${1}" "lefford.${subcommand%:*}" "${subcommand#*:}.yaml" "${@:2}";
  elif [[ " ${general_subcommands[*]} " =~ " ${subcommand%:*} " ]]; then
    lefford:ansible_task "${1}" "lefford.${subcommand%:*}" "${subcommand#*:}.yaml" "${@:2}";
  elif [[ " ${k8s_cluster_subcommands[*]} " =~ " ${subcommand} " ]]; then
    lefford:k8s_cluster "${subcommand}" "${@}";
  else
    lefford:usage;
  fi;
}

lefford "${@}";
exit $?;
