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

# Perform an operation on an LXC container.
function lefford:pve_lxc() {
  : "${2?"Usage: ${FUNCNAME[0]}:${1:='<SUBCOMMAND>'} <HOSTNAME|GROUP>"}";
  local subcommand="${1}";
  local host_expression="${2}";
  local args="${@:3}";
  # We need to use explicit gathering for LXC containers because they are not
  # always provisioned yet.
  ANSIBLE_GATHERING='explicit' \
    lefford:ansible_task \
    "${host_expression}" \
    'lefford.pve_lxc' \
    "${subcommand}.yaml" \
    "${args}";
}

# Perform an operation on the Kubernetes cluster.
function lefford:pve_k8s() {
  : "${1?"Usage: ${FUNCNAME[0]}:${1:='<SUBCOMMAND>'} [HOSTNAME|GROUP]"}";
  local subcommand="${1}";
  local host_expression="${2:-pve_k8s}";
  local args="${@:3}";
  # We don't know if the cluster is provisioned yet, so we need to use explicit
  # gathering.
  ANSIBLE_GATHERING='explicit' \
    lefford:ansible_task \
    "${host_expression}" \
    'lefford.pve_k8s' \
    "${subcommand}.yaml" \
    "${args}";
}

# Perform a Docker operation.
function lefford:docker() {
  : "${2?"Usage: ${FUNCNAME[0]}:${1:='<SUBCOMMAND>'} [HOSTNAME|GROUP]"}";
  local subcommand="${1}";
  local host_expression="${2:-pve_k8s}";
  local args="${@:3}";
  # We don't know if the cluster is provisioned yet, so we need to use explicit
  # gathering.
  ANSIBLE_GATHERING='explicit' \
    lefford:ansible_task \
    "${host_expression}" \
    'lefford.docker' \
    "${subcommand}.yaml" \
    "${args}";
}

# Perform a dotfiles operation.
function lefford:dotfiles() {
  : "${2?"Usage: ${FUNCNAME[0]}:${1:='<SUBCOMMAND>'} [HOSTNAME|GROUP]"}";
  local subcommand="${1}";
  local host_expression="${2:-pve_k8s}";
  local args="${@:3}";
  # We don't know if the cluster is provisioned yet, so we need to use explicit
  # gathering.
  ANSIBLE_GATHERING='explicit' \
    lefford:ansible_task \
    "${host_expression}" \
    'lefford.dotfiles' \
    "${subcommand}.yaml" \
    "${args}";
}

# Perform an operation on the Proxmox VE node.
function lefford:pve_node() {
  : "${1?"Usage: ${FUNCNAME[0]}:${1:='<SUBCOMMAND>'}"}";
  local subcommand="${1}";
  local args="${@:2}";
  # If we need to perform an operation on the node, we can assume that it is
  # already provisioned.
  ANSIBLE_GATHERING='implicit' \
    lefford:ansible_task \
    'lefford' \
    'lefford.pve_node' \
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
  printf "${subcommand_column}" 'pve_k8s:create' 'Create cluster (but do not deploy tasks).';
  printf "${subcommand_column}" 'pve_k8s:recreate' 'Destroy and rereate the cluster (but do not deploy tasks).';
  printf "${subcommand_column}" 'pve_k8s:destroy' 'Destroy the cluster.';
  printf "${subcommand_column}" 'pve_k8s:reset' 'Reset the cluster and deploy tasks.';
  printf "${subcommand_column}" 'pve_k8s:setup' 'Setup the cluster and deploy tasks.';
  printf "${subcommand_column}" 'pve_k8s:stop' 'Stop tasks on the clustter.';
  echo '';
}

# Retrieve list of roles.
function lefford:list_roles() {
  for i in "${ansible_path}/roles/"lefford.*; do
    echo "${i#*\.}";
    for j in "${i}/tasks/"*.yaml; do
      echo "${i#*\.}:$(basename "${j##*/}" '.yaml')";
    done;
  done;
}

# Print autocomplete script.
function lefford:autocomplete() {
  local old_ifs="${IFS}";
  IFS=\ ;
  IFS=$'\n' read -d '' -r -a discovered_subcommands < <(lefford:list_roles);
  local all_subcommands=(
    'usage'
    'ansible_task'
    'edit_vault'
    'list_roles'
    'autocomplete'
    "$(echo "${discovered_subcommands[*]}")"
  )
  local subcommands_string="$(echo "${all_subcommands[*]}")";
  echo complete -W "'"${subcommands_string}"'" lefford;
  IFS="${old_ifs}";
}

# Primary function.
function lefford() {
  : "${1?"Usage: ${FUNCNAME[0]} <SUBCOMMAND> [HOSTNAME|GROUP] [...ARGUMENTS]"}";
  local subcommand="${1}";
  export OBJC_DISABLE_INITIALIZE_FORK_SAFETY='YES';
  export K8S_AUTH_KUBECONFIG='~/.kube/config';
  shift;
  if type lefford:"${subcommand%:*}" > /dev/null 2>&1; then
    lefford:"${subcommand%:*}" "${subcommand#*:}" "${@}";
  else
    lefford:usage;
  fi;
}

lefford "${@}";
exit $?;
