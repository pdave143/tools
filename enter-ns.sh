#!/bin/bash
VERSION=1.0.0
AUTHOR="Peter N"
: '
Description: 
  This tool can be used for debugging, where you do not have access
  to tools such as kubectl and need to access a container namespace
  keep in mind, when you enter all namespaces, you will not have access to the
  underlying host network debugging tools
'

validate_requirements() {
  if ! command -v crictl &>/dev/null; then
    printf "%s\n" "Error: crictl binary is missing."
    exit 1
  elif [ ! -f /etc/crictl.yaml ]; then
    printf "%s\n" "Error: crictl config file is missing."
    exit 1
  fi
}

#get PID of selected pod
get_pod_pid() {
  local pod_name="$1"
  crictl inspect "$(crictl ps | grep -w "$pod_name" | awk '{print $1}')" | \
    grep -m1 'pid' | grep -o '[0-9]\+' || echo "PID not found"
}

enter_namespace() {
  local namespace="$1"
  case $namespace in
    "net") nsenter -t "$POD_PID" -n;;
    "mount") nsenter -t "$POD_PID" -m;;
    "all") nsenter -t "$POD_PID";;
    "quit") exit;;
    *) printf "%s\n" "Invalid Option";;
  esac
}

validate_requirements

printf '%s\n' "Select a pod below to inspect"
echo

#get list of pods
pod_list=($(crictl ps | sed '1d' | awk '{print $NF}'))
select pod in "${pod_list[@]}" quit; do
  if [[ "$pod" == "quit" ]]; then exit; fi
  if [[ -z "$pod" ]]; then
    printf "%s\n" "Invalid selection, try again."
    continue
  fi

  printf "%s\n" "You selected $pod"
  POD_PID=$(get_pod_pid "$pod")

  if [[ -z "$POD_PID" ]]; then
    printf "%s\n" "Error: Could not retrieve PID for pod $pod."
    continue
  fi

  printf "%s\n" "Please select a namespace to enter"
  select namespace in net mount all quit; do
    if [[ "$namespace" == "quit" ]]; then exit; fi
    enter_namespace "$namespace"
    break
  done
done
