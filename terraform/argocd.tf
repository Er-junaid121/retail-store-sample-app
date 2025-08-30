# =============================================================================
# ARGOCD INSTALLATION AND CONFIGURATION
# =============================================================================

# Wait for the cluster and add-ons to be ready
resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on = [
    module.retail_app_eks,
    module.eks_addons
  ]
}

# =============================================================================
# ARGOCD HELM INSTALLATION
# =============================================================================

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # ArgoCD configuration values
  values = [
    yamlencode({
      # Server configuration
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = false  # We'll use port-forward for access
        }
        # Enable insecure mode for easier local access
        extraArgs = [
          "--insecure"
        ]
      }
      
      # Controller configuration
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      
      # Repo server configuration
      repoServer = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
      
      # Redis configuration
      redis = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [time_sleep.wait_for_cluster]
}

# =============================================================================
# WAIT FOR ARGOCD TO BE READY
# =============================================================================

resource "time_sleep" "wait_for_argocd" {
  create_duration = "60s"
  depends_on      = [helm_release.argocd]
}

# =============================================================================
# DEPLOY ARGOCD APPLICATIONS USING KUBERNETES PROVIDER
# =============================================================================

# Create retail-store namespace
resource "kubernetes_namespace" "retail_store" {
  metadata {
    name = "retail-store"
  }
  depends_on = [time_sleep.wait_for_argocd]
}

# Deploy ArgoCD Project
resource "kubernetes_manifest" "retail_store_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "retail-store"
      namespace = var.argocd_namespace
    }
    spec = {
      description = "Retail Store Sample Application"
      sourceRepos = [
        "https://github.com/LondheShubham153/retail-store-sample-app"
      ]
      destinations = [{
        namespace = "retail-store"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = [
        { group = "", kind = "Namespace" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "cert-manager.io", kind = "ClusterIssuer" }
      ]
      namespaceResourceWhitelist = [
        { group = "", kind = "ConfigMap" },
        { group = "", kind = "Secret" },
        { group = "", kind = "Service" },
        { group = "", kind = "ServiceAccount" },
        { group = "apps", kind = "Deployment" },
        { group = "apps", kind = "StatefulSet" },
        { group = "networking.k8s.io", kind = "Ingress" },
        { group = "autoscaling", kind = "HorizontalPodAutoscaler" },
        { group = "policy", kind = "PodDisruptionBudget" }
      ]
    }
  }
  depends_on = [time_sleep.wait_for_argocd]
}

# Deploy ArgoCD Applications
resource "kubernetes_manifest" "retail_store_ui" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "retail-store-ui"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "2"
      }
    }
    spec = {
      project = "retail-store"
      source = {
        repoURL        = "https://github.com/LondheShubham153/retail-store-sample-app"
        targetRevision = "main"
        path           = "src/ui/chart"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "retail-store"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [kubernetes_manifest.retail_store_project, kubernetes_namespace.retail_store]
}

resource "kubernetes_manifest" "retail_store_cart" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "retail-store-cart"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
    }
    spec = {
      project = "retail-store"
      source = {
        repoURL        = "https://github.com/LondheShubham153/retail-store-sample-app"
        targetRevision = "main"
        path           = "src/cart/chart"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "retail-store"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [kubernetes_manifest.retail_store_project, kubernetes_namespace.retail_store]
}

resource "kubernetes_manifest" "retail_store_catalog" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "retail-store-catalog"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
    }
    spec = {
      project = "retail-store"
      source = {
        repoURL        = "https://github.com/LondheShubham153/retail-store-sample-app"
        targetRevision = "main"
        path           = "src/catalog/chart"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "retail-store"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [kubernetes_manifest.retail_store_project, kubernetes_namespace.retail_store]
}

resource "kubernetes_manifest" "retail_store_checkout" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "retail-store-checkout"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
    }
    spec = {
      project = "retail-store"
      source = {
        repoURL        = "https://github.com/LondheShubham153/retail-store-sample-app"
        targetRevision = "main"
        path           = "src/checkout/chart"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "retail-store"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [kubernetes_manifest.retail_store_project, kubernetes_namespace.retail_store]
}

resource "kubernetes_manifest" "retail_store_orders" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "retail-store-orders"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
    }
    spec = {
      project = "retail-store"
      source = {
        repoURL        = "https://github.com/LondheShubham153/retail-store-sample-app"
        targetRevision = "main"
        path           = "src/orders/chart"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "retail-store"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [kubernetes_manifest.retail_store_project, kubernetes_namespace.retail_store]
}
