# main.tf

# NOTE: This script is for security testing purposes ONLY. 
# Do NOT use this in a production environment.

# Configure the Google provider (assuming provider and variable setup from the previous example)

resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = true 
}

# ----------------------------------------------------
# VULNERABLE GKE CLUSTER RESOURCE
# ----------------------------------------------------
resource "google_container_cluster" "vulnerable_gke_cluster" {
  name               = var.cluster_name
  location           = var.gcp_zone
  network            = google_compute_network.vpc_network.name
  initial_node_count = 1 
  
  # 🔴 VULNERABILITY 1: Master Authorized Networks set to 0.0.0.0/0 (Open to the World)
  # This allows *any* IP address on the internet to attempt to connect to the 
  # cluster's master endpoint using credentials. 
  master_authorized_networks_config {
    cidr_blocks {
      display_name = "Allow-All"
      cidr_block   = "0.0.0.0/0"
    }
  }

  master_auth {} # Required for the master_authorized_networks_config block

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform", # Broad scope
    ]

    # 🔴 VULNERABILITY 2: Disable Workload Identity and use broad OAuth scope
    # This falls back to using the default Compute Engine service account 
    # and a very broad scope, increasing the blast radius if a node is compromised.

    # 🔴 VULNERABILITY 3: Legacy Metadata Server Endpoint
    # This makes it easier for an attacker who achieves RCE on a container to 
    # steal the node's service account credentials from the metadata server.
    metadata = {
      disable-legacy-endpoints = "false"
    }
  }

  # 🔴 VULNERABILITY 4: No Network Policy Enabled
  # Network policy is disabled, meaning any pod can communicate with any other 
  # pod/service in the cluster, facilitating lateral movement after a breach.
  enable_network_policy = false

  # Node pools are managed separately, often leading to unmanaged node pool configurations
}

# ----------------------------------------------------
# VULNERABLE NODE POOL
# ----------------------------------------------------
resource "google_container_node_pool" "vulnerable_nodepool" {
  name       = "${var.cluster_name}-vulnerable-pool"
  location   = var.gcp_zone
  cluster    = google_container_cluster.vulnerable_gke_cluster.name
  node_count = 1

  # 🔴 VULNERABILITY 5: HTTP/HTTPS access on Node Firewall (If not controlled by VPC rules)
  # In a vulnerable context, leaving the default firewall rules or allowing broad 
  # ingress to the nodes themselves can expose unnecessary ports. 
  # While GKE manages node security groups, the broad permissions on the nodes
  # (VULNERABILITY 2 & 3) are the primary risks here.

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    
    # Using a broad machine type increases costs and the resources available to an attacker.
  }
}

# Output is not security relevant, so it is omitted for brevity.
