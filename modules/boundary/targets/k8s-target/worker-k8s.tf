resource "kubernetes_config_map" "config" {
  metadata {
    name = "boundary-k8s-worker-config"
  }

  data = {
    "boundary-worker.hcl" = "${templatefile("${path.root}/files/boundary/boundary-worker-k8s-configmap.tpl", {
      boundary_cluster_id = trimspace(file("${path.root}/generated/boundary_cluster_id")),
      public_addr       = kubernetes_service_v1.service.status.0.load_balancer.0.ingress.0.hostname
    })}"
  }
}
/*
resource "kubernetes_deployment_v1" "deployment" {
  metadata {
    name = "boundary-worker-k8s"
    labels = {
      app       = "boundary",
      component = "worker",
      env       = "k8s"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app       = "boundary",
        component = "worker",
        env       = "k8s"
      }
    }

    template {
      metadata {
        labels = {
          app       = "boundary",
          component = "worker",
          env       = "k8s"
        }
      }

      spec {
        container {
          image   = "hashicorp/boundary-worker-hcp:0.11-hcp"
          name    = "boundary-worker"
          command = ["boundary-worker", "server", "-config", "/etc/boundary/boundary-worker.hcl"]
          port {
            container_port = 9202
          }
          volume_mount {
            mount_path = "/etc/boundary"
            name       = "boundary-config"
          }
          volume_mount {
            mount_path = "/home/boundary"
            name       = "worker"
          }
          security_context {
            privileged = true
          }
        }
        volume {
          name = "boundary-config"
          config_map {
            name = "boundary-k8s-worker-config"
          }
        }
        volume {
          name = "worker"
          persistent_volume_claim {
            claim_name = "worker-pv-claim"
          }
        }
      }
    }
  }
}
*/

resource "kubernetes_stateful_set_v1" "statefulset" {
  metadata {
    name = "boundary-worker-k8s"
    labels = {
      app       = "boundary",
      component = "worker",
      env       = "k8s"
    }
  }

  spec {
    replicas = 1
    service_name = "boundary-k8s-worker-svc"

    selector {
      match_labels = {
        app       = "boundary",
        component = "worker",
        env       = "k8s"
      }
    }

    template {
      metadata {
        labels = {
          app       = "boundary",
          component = "worker",
          env       = "k8s"
        }
      }

      spec {
        container {
          image   = "hashicorp/boundary-worker-hcp:0.11-hcp"
          name    = "boundary-worker"
          command = ["boundary-worker", "server", "-config", "/etc/boundary/boundary-worker.hcl"]
          port {
            container_port = 9202
          }
          volume_mount {
            mount_path = "/etc/boundary"
            name       = "boundary-config"
          }
          volume_mount {
            mount_path = "/home/boundary"
            name       = "worker-data"
          }
          security_context {
            privileged = true
          }
        }
        volume {
          name = "boundary-config"
          config_map {
            name = "boundary-k8s-worker-config"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "worker-data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "5Gi"
          }
        }
      }
    }
  }
}


resource "kubernetes_service_v1" "service" {
  metadata {
    name = "boundary-k8s-worker-svc"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    }
  }
  spec {
    selector = {
      app       = "boundary",
      component = "worker",
      env       = "k8s"
    }
    port {
      port        = 9202
      target_port = 9202
      name        = "data"
    }
    type = "LoadBalancer"
  }
}

resource "null_resource" "register_k8s_worker" {
  provisioner "local-exec" {
    command = "kubectl exec -i $(kubectl get po -oname | grep -i boundary) -- cat /home/boundary/worker1/auth_request_token > ${path.root}/generated/k8s_auth_request_token"
  }

  provisioner "local-exec" {
    command = "export BOUNDARY_ADDR=${var.hcp_boundary_address} && export AUTH_ID=$(boundary auth-methods list -format json | jq \".items[].id\" -r) && export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD=${var.hcp_boundary_password} && boundary authenticate password -auth-method-id=$AUTH_ID -login-name=${var.hcp_boundary_admin} -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD && boundary workers create worker-led -worker-generated-auth-token=${trimspace(file("${path.root}/generated/k8s_auth_request_token"))}"
  }

  depends_on = [
    kubernetes_stateful_set_v1.statefulset
    /* kubernetes_deployment_v1.deployment */
  ]
}
/*
resource "kubernetes_persistent_volume_claim_v1" "boundary_worker_pv_claim" {
  metadata {
    name = "worker-pv-claim"
    labels = {
      app       = "boundary",
      component = "worker",
      env       = "k8s"
    }
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}
*/