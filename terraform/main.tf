locals {
  app_data = jsondecode(file("${path.module}/applications.json"))
  apps = [for app in local.app_data.applications : app]
}

resource "kubernetes_deployment" "application" {
  for_each = {
    for app in local.apps : app.name => app
  }
  metadata {
    name = each.value.name
    labels = {
      key = each.value.name
    }
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        key = each.value.name
      }
    }

    template {
      metadata {
        labels = {
          key = each.value.name
        }
      }

      spec {
        container {
          image = each.value.image
          name  = each.value.name
          args = formatlist("-%s",compact(split(" -", format(" %s",each.value.args))))
          port {
            container_port = each.value.port
        }
      }
      }
    }
  }
}

resource "kubernetes_service" "services" {
  for_each = {
    for app in local.apps : app.name => app
  }
  metadata {
    name = format("%s-service",each.value.name)
  }

  spec {
 
    selector = {
        key = each.value.name
    }

    port {
		port = each.value.port
		target_port = each.value.port
	}
  }
  depends_on = [
    kubernetes_deployment.application
  ]
}

resource "kubernetes_ingress_v1" "ingress" {
  for_each = {
    for app in local.apps : app.name => app
  }
  metadata {
    name = format("%s-ingress",each.value.name)
	annotations = {
	"kubernetes.io/ingress.class" : "nginx"
    "kubernetes.io/elb.port" : "80"
	"nginx.ingress.kubernetes.io/canary" : each.value.name != "foo" ? "true" : "false"         
    "nginx.ingress.kubernetes.io/canary-weight" : each.value.traffic_weight
	}
  }

  spec {
    rule {
	  host = "www.example.com"
      http {
        path {
          backend {
            service {
              name = format("%s-service",each.value.name)
              port {
                number = each.value.port
              }
            }
          }
		  path_type = "Prefix"
          path = "/"
        }
      }
    }
  }
  depends_on = [
    kubernetes_deployment.application,
	kubernetes_service.services
  ]
}

