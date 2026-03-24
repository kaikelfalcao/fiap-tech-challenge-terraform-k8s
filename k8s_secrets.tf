# Namespace da aplicação — criado aqui para garantir que existe antes do deploy do app.
# O codebase repo cria e gerencia o secret `autoflow-secrets` neste namespace.
resource "kubernetes_namespace" "autoflow" {
  metadata {
    name = "autoflow"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}
