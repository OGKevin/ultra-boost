resource "digitalocean_kubernetes_cluster" "cluster" {
  name    = "cluster"
  region  = "ams3"
  version = "1.21.2-do.2"

  node_pool {
    name       = "autoscale-worker-pool"
    size       = "s-8vcpu-16gb"
    node_count = 1
  }
}
