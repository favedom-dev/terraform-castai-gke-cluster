resource "castai_gke_cluster" "castai_cluster" {
  project_id                 = var.project_id
  location                   = var.gke_cluster_location
  name                       = var.gke_cluster_name
  delete_nodes_on_disconnect = var.delete_nodes_on_disconnect
  credentials_json           = var.gke_credentials
}

resource "castai_node_configuration" "this" {
  for_each = {for k, v in var.node_configurations : k => v}

  cluster_id = castai_gke_cluster.castai_cluster.id

  name           = try(each.value.name, each.key)
  disk_cpu_ratio = try(each.value.disk_cpu_ratio, 5)
  subnets        = try(each.value.subnets, null)
  ssh_public_key = try(each.value.ssh_public_key, null)
  image          = try(each.value.image, null)
  tags           = try(each.value.tags, {})
}

resource "helm_release" "castai_agent" {
  name             = "castai-agent"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-agent"
  namespace        = "castai-agent"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true

  values = var.agent_values

  set {
    name  = "provider"
    value = "gke"
  }

  set {
    name  = "additionalEnv.STATIC_CLUSTER_ID"
    value = castai_gke_cluster.castai_cluster.id
  }

  set {
    name  = "createNamespace"
    value = "false"
  }

  dynamic "set" {
    for_each = var.api_url != "" ? [var.api_url] : []
    content {
      name  = "apiURL"
      value = var.api_url
    }
  }

  dynamic "set" {
    for_each = var.castai_components_labels
    content {
      name  = "podLabels.${set.key}"
      value = set.value
    }
  }

  set_sensitive {
    name  = "apiKey"
    value = castai_gke_cluster.castai_cluster.cluster_token
  }
}

resource "helm_release" "castai_evictor" {
  name             = "castai-evictor"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-evictor"
  namespace        = "castai-agent"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true

  values = var.evictor_values

  dynamic "set" {
    for_each = var.castai_components_labels
    content {
      name  = "podLabels.${set.key}"
      value = set.value
    }
  }

  depends_on = [helm_release.castai_agent]

  lifecycle {
    ignore_changes = [set, version]
  }
}

resource "helm_release" "castai_cluster_controller" {
  name             = "cluster-controller"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-cluster-controller"
  namespace        = "castai-agent"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true

  values = var.cluster_controller_values

  set {
    name  = "castai.clusterID"
    value = castai_gke_cluster.castai_cluster.id
  }

  dynamic "set" {
    for_each = var.api_url != "" ? [var.api_url] : []
    content {
      name  = "castai.apiURL"
      value = var.api_url
    }
  }

  set_sensitive {
    name  = "castai.apiKey"
    value = castai_gke_cluster.castai_cluster.cluster_token
  }

  dynamic "set" {
    for_each = var.castai_components_labels
    content {
      name  = "podLabels.${set.key}"
      value = set.value
    }
  }

  depends_on = [helm_release.castai_agent]

  lifecycle {
    ignore_changes = [version]
  }
}

resource "helm_release" "castai_spot_handler" {
  name             = "castai-spot-handler"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-spot-handler"
  namespace        = "castai-agent"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true

  values = var.spot_handler_values

  set {
    name  = "castai.provider"
    value = "gcp"
  }

  set {
    name  = "createNamespace"
    value = "false"
  }

  dynamic "set" {
    for_each = var.api_url != "" ? [var.api_url] : []
    content {
      name  = "castai.apiURL"
      value = var.api_url
    }
  }

  set {
    name  = "castai.clusterID"
    value = castai_gke_cluster.castai_cluster.id
  }

  dynamic "set" {
    for_each = var.castai_components_labels
    content {
      name  = "podLabels.${set.key}"
      value = set.value
    }
  }

  depends_on = [helm_release.castai_agent]
}

resource "castai_autoscaler" "castai_autoscaler_policies" {
  autoscaler_policies_json = var.autoscaler_policies_json
  cluster_id               = castai_gke_cluster.castai_cluster.id

  depends_on = [helm_release.castai_agent, helm_release.castai_evictor]
}

resource "helm_release" "castai_sec_agent" {
  count = var.install_security_agent == true ? 1 : 0

  name             = "castai-sec-agent"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-sec-agent"
  namespace        = "castai-agent"
  create_namespace = true
  cleanup_on_fail  = true

  values = var.sec_agent_values

  set {
    name  = "castai.apiURL"
    value = var.api_url
  }

  set {
    name  = "castai.clusterID"
    value = castai_gke_cluster.castai_cluster.id
  }

  set_sensitive {
    name  = "castai.apiKey"
    value = castai_gke_cluster.castai_cluster.cluster_token
  }

  set {
    name = "structuredConfig.provider"
    value = "gke"
  }
}

resource "helm_release" "castai_pod_node_lifecycle" {
  name             = "castai-pod-node-lifecycle"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-pod-node-lifecycle"
  namespace        = "castai-agent"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true

  values = var.pod_node_lifecycle_values

  depends_on = [helm_release.castai_agent]

  lifecycle {
    ignore_changes = [version]
  }
}