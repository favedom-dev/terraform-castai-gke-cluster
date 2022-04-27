output "cluster_id" {
  value = castai_gke_cluster.castai_cluster.id
  description = "CAST.AI cluster id, which can be used for accessing cluster data using API"
  sensitive = true
}