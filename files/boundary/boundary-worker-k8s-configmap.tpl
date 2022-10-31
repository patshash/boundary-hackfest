hcp_boundary_cluster_id = "${boundary_cluster_id}"
disable_mlock = true
listener "tcp" {
  purpose = "proxy"
  address = "0.0.0.0:9202"
}

worker {
  public_addr = "${public_addr}"
  auth_storage_path = "/home/boundary/worker1"
  tags {
    type = "eks"
  }
}