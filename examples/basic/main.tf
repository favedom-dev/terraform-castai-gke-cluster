provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

provider "castai" {
  api_token = var.castai_api_token
}

module "castai-gke-iam" {
  source = "castai/gke-iam/castai"

  project_id       = var.project_id
  gke_cluster_name = var.cluster_name

  depends_on = [module.gke]
}

module "castai-gke-cluster" {
  source = "../../"

  project_id           = var.project_id
  gke_cluster_name     = var.cluster_name
  gke_cluster_location = module.gke.location

  gke_credentials            = module.castai-gke-iam.private_key
  delete_nodes_on_disconnect = true

  // Set default node configuration which will be used for all CAST provisioned nodes unless specific node configuration is selected.
  default_node_configuration = module.castai-gke-cluster.castai_node_configurations["default"]

  node_configurations = {
    default = {
      disk_cpu_ratio = 25
      subnets        = [module.vpc.subnets_ids[0]]
      tags           = {
        "node-config" : "default"
      }
    }
  }

  # Full schema can be found here https://api.cast.ai/v1/spec/#/PoliciesAPI/PoliciesAPIUpsertClusterPolicies
  autoscaler_policies_json = <<-EOT
    {
        "enabled": true,
        "isScopedMode": false,
        "unschedulablePods": {
            "enabled": true
        },
        "spotInstances": {
            "enabled": true,
            "clouds": ["gcp"],
            "spotBackups": {
                "enabled": true
            }
        },
        "nodeDownscaler": {
            "emptyNodes": {
                "enabled": true
            }
        }
    }
  EOT

  // depends_on helps terraform with creating proper dependencies graph in case of resource creation and in this case destroy
  // module "castai-gke-cluster" has to be destroyed before module "castai-gke-iam" and "module.gke"
  depends_on = [module.gke, module.castai-gke-iam]
}