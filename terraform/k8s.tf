resource "digitalocean_kubernetes_cluster" "dev-cluster" {
  name    = "dev-cluster"
  region  = "ams3"
  version = "1.21.2-do.2"

  node_pool {
    name       = "autoscale-worker-pool"
    size       = "s-8vcpu-16gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 5
  }
}
