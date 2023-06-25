# RHACM for Declarative OpenShift Cluster Configuration
This repository contains the configuration files to generate declarative OpenShift clusters using Red Hat Advanced Cluster Management (RHACM).
> NOTE: This helm chart was created to be run as a appOfapp in ArgoCD with a cluster running RHACM.

## Pre-requirements
1. A _hub_ cluster with RHACM installed.
2. [Sealed-Secrets](https://github.com/bitnami-labs/sealed-secrets) installed on the Hub cluster with a local certificate (from the controller in the cluster) present in the same directory as the _script.sh_ file.
3. OpenShift on VMware 4.12 or lower. 4.13 and later would require updates to the install-config.yaml file.
4. The normal [pre-requirements](https://docs.openshift.com/container-platform/4.12/installing/installing_vsphere/installing-vsphere-installer-provisioned.html) for doing IPI installations on VMware with OpenShift.

## Clusters

The configuration:

- **Name**: The name of the cluster.
- **Base Domain**: The base domain for the cluster. 
- **Image Set Reference**: The version of OpenShift to be installed.
- **Platform**: The platform on which the cluster is deployed.
  - **vSphere**:
    - **Cluster**: The vSphere cluster for the cluster.
    - **vCenter**: The URL of the vCenter server for the cluster.
    - **Datacenter**: The datacenter for the cluster.
    - **Default Datastore**: The default datastore for the cluster.
    - **Network**: The network configuration for the cluster.
- **Secrets**: Contains sensitive information related to the cluster.
  - **installConfig**: The value of the encrypted install-config file.
- **Network Configuration**: The network configuration for the cluster.
  - **API VIP**: The virtual IP address for the API of the cluster.
  - **Ingress VIP**: The virtual IP address for the ingress of the cluster.
  - **Cluster Network**: The network range for the cluster.
  - **Host Prefix**: The host prefix for the cluster.
  - **Machine Network**: The network range for the machines in the cluster.
  - **Service Network**: The network range for the services in the cluster.


## Usage
1. Open the values.yaml file and provide the necessary values for the cluster(s) you want to create.
2. Run the script to generate the declarative OpenShift clusters. The script will prompt you to validate the data and enter the VMware admin username and password.
3. The script will perform the following steps:
    * Generate an install-config.yaml file based on the provided values.
    * Create a secret with the base64-encoded value of the install-config.yaml file.
    * Create a sealed-secret using the base64-encoded install-config.yaml file. The sealed-secret value will be inserted into the respective cluster's values.yaml file.
    * Clean up all the temporary files generated during the process.
4. Push the changes to your Git repository to trigger the deployment and management of the clusters by RHACM.