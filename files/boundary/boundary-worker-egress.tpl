disable_mlock = true

listener "tcp" {
    address = "${private_ip}:9202"
    purpose = "proxy"
    tls_disable = true
}
  
worker {
    # Name attr must be unique
    public_addr = "${private_ip}"
    initial_upstreams = ["${upstream_worker_ip}:9202"]
    auth_storage_path = "/etc/boundary/worker1"
    tags {
        type = ["egress", "worker2", "downstream"]
    }
}
