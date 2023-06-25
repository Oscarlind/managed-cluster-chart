#!/bin/bash

# Read the values.yaml file
values_file="values.yaml"
content=$(cat "$values_file")

# Initialize install-config.yaml
config_file="install-config.yaml"


# Extract the names and base domains
names=($(echo "$content" | grep -oP '(?<=- name: ).*'))
base_domains=($(echo "$content" | grep -oP '(?<=baseDomain: ).*'))

# Function to extract network values based on the chosen cluster
extract_network_values() {
  local cluster_content=$1

  api_vip=$(echo "$cluster_content" | grep -oP '(?<=apiVIP: ).*')
  ingress_vip=$(echo "$cluster_content" | grep -oP '(?<=ingressVIP: ).*')
  cluster_network=$(echo "$cluster_content" | grep -oP '(?<=clusterNetwork: ).*')
  host_prefix=$(echo "$cluster_content" | grep -oP '(?<=HostPrefix: ).*')
  machine_network=$(echo "$cluster_content" | grep -oP '(?<=machineNetwork: ).*')
  service_network=$(echo "$cluster_content" | grep -oP '(?<=serviceNetwork: ).*')
}


# Function to extract vsphere values based on the chosen cluster
extract_vsphere_values() {
  local cluster_content=$1

  vsphere_cluster=$(echo "$cluster_content" | grep -oP '(?<=cluster: ).*')
  vcenter_url=$(echo "$cluster_content" | grep -oP '(?<=vCenter: ).*')
  datacenter=$(echo "$cluster_content" | grep -oP '(?<=datacenter: ).*')
  default_datastore=$(echo "$cluster_content" | grep -oP '(?<=defaultDatastore: ).*')
  network=$(echo "$cluster_content" | grep -oP '(?<=network: ).*')
}

display_header() {
  local header_text=$1
  echo ""
  echo "=== $header_text ==="
  echo "=========================="
}

display_instructions() {
  local instruction_text=$1
  echo ""
  echo "* $instruction_text"
}

# Display the list of cluster names to the user
clear
display_header "Available Clusters"
for ((i=0; i<${#names[@]}; i++)); do
  echo "$(($i+1)). ${names[$i]}"
done

# Prompt the user to choose a cluster
display_instructions "Please enter the number corresponding to the desired cluster:"
read -p "Choice: " choice

# Validate the user's choice
re='^[0-9]+$'
if ! [[ $choice =~ $re ]] || ((choice < 1 || choice > ${#names[@]})); then
  echo "Invalid choice. Exiting..."
  exit 1
fi

# Adjust the index to match array indexing (0-based)
index=$(($choice - 1))

# Get the chosen cluster name and base domain
cluster_name=${names[$index]}
base_domain=${base_domains[$index]}

# Find the cluster content based on the chosen cluster name
cluster_content=$(echo "$content" | awk -v cluster="$cluster_name" '/- name: / {flag = ($3 == cluster)} flag')

# Extract the network values based on the chosen cluster
extract_network_values "$cluster_content"

# Extract the vsphere values based on the chosen cluster
extract_vsphere_values "$cluster_content"


# Print the chosen cluster name, base domain, and network values
display_header "Chosen Cluster"
echo "Cluster name: $cluster_name"
echo "Base domain:  $base_domain"


display_header "Network Fields"
echo "API VIP:         $api_vip"
echo "Ingress VIP:     $ingress_vip"
echo "Cluster Network: $cluster_network"
echo "  Host Prefix:   $host_prefix"
echo "Machine Network: $machine_network"
echo "Service Network: $service_network"

display_header "vSphere Fields"
echo "vSphere Cluster:     $vsphere_cluster"
echo "vCenter URL:         $vcenter_url"
echo "Datacenter:          $datacenter"
echo "Default Datastore:   $default_datastore"
echo "Network:             $network"

display_instructions "Press Enter to continue..."
read -s -n 1

# Prompt for credentials
display_instructions "Please enter the vSphere username:"
read -p "Username: " vsphere_username

display_instructions "Please enter the vSphere password:"
read -s -p "Password: " vsphere_password
echo ""

# Create the install-config file
cat > "$config_file" <<EOF
---
apiVersion: v1
metadata:
  name: $cluster_name
baseDomain: $base_domain
proxy:
  httpProxy: http://proxy
  httpsProxy: http://proxy
  noProxy: .local
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  replicas: 3
  platform:
    vsphere:
      cpus:  4
      coresPerSocket:  2
      memoryMB:  16384
      osDisk:
        diskSizeGB: 120
compute:
- hyperthreading: Enabled
  architecture: amd64
  name: 'worker'
  replicas: 3
  platform:
    vsphere:
      cpus:  4
      coresPerSocket:  2
      memoryMB:  16384
      osDisk:
        diskSizeGB: 120
networking:
  networkType: OVNKubernetes
  clusterNetwork:
  - cidr: $cluster_network
    hostPrefix: $host_prefix
  machineNetwork:
  - cidr: $machine_network
  serviceNetwork:
  - $service_network
platform:
  vsphere:
    vCenter: $vcenter_url
    username: $vsphere_username
    password: $vsphere_password
    datacenter: $datacenter
    defaultDatastore: $default_datastore
    cluster: $vsphere_cluster
    apiVIP: $api_vip
    ingressVIP: $ingress_vip
    network: $network
pullSecret: "" # skip, hive will inject based on it's secrets
sshKey: |-
    REPLACE_WITH_ACTUAL_SSH_KEY
    ...
additionalTrustBundle: |-
    -----BEGIN CERTIFICATE-----
    INSERT_PROXY_CERTIFICATE_HERE
    -----END CERTIFICATE-----
EOF

# Base64 encode the configuration file
encoded_config=$(base64 -w 0 "$config_file")

# Remove the install-config file
rm $config_file

# Create the secrets file
secrets_file="secrets.yaml"

cat > "$secrets_file" <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: $cluster_name-install-config
  namespace: '$cluster_name'
type: Opaque
data:
  install-config.yaml: $encoded_config
EOF

#echo "Secrets file '$secrets_file' generated successfully."

# # Run kubeseal on the secrets file
 encrypted_secrets_file="encrypted-secrets.json"
 kubeseal --cert mycert.pem < "$secrets_file" > "$encrypted_secrets_file"

# Read the encrypted secrets file
encrypted_secrets_file="encrypted-secrets.json"
encrypted_data=$(cat "$encrypted_secrets_file" | jq '.spec.encryptedData."install-config.yaml"')


install_config_value=$(echo "$encrypted_data" | sed -e 's/^"//' -e 's/"$//')

# Remove existing installConfig line
if sed -i "/- name: $cluster_name/{:a; n; /installConfig:/ {s|.*|      installConfig: $install_config_value|; b}; ba}" "$values_file"; then
display_header "values.yaml"
echo "$cluster_name"
echo "secrets"
echo "  installConfig: ${install_config_value:0:10}..."
else
display_header "values.yaml"
echo "Failed to update values.yaml. Please add the encrypted data to the installConfig field manually"
fi
