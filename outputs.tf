output "cluster_endpoint" {
  value = google_container_cluster.gke_cluster.endpoint
}

output "static_ip" {
  value = google_compute_address.static_ip.address
}