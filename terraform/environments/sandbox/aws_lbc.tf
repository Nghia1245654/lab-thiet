# 1. IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_lbc" {
  name        = "tf1-sandbox-aws-lbc-policy"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/aws-load-balancer-controller-policy.json")
}

# 2. IAM Role for AWS Load Balancer Controller (IRSA)
data "aws_iam_policy_document" "aws_lbc_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.compute.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.compute.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.compute.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_lbc" {
  name               = "tf1-sandbox-aws-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc_assume_role.json
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  policy_arn = aws_iam_policy.aws_lbc.arn
  role       = aws_iam_role.aws_lbc.name
}

# 3. Kubernetes Service Account
resource "kubernetes_service_account" "aws_lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lbc.arn
    }
  }

  depends_on = [module.compute]
}

# 4. Helm Release for AWS Load Balancer Controller
resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = module.compute.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_lbc.metadata[0].name
  }

  set {
    name  = "region"
    value = "us-east-1"
  }

  set {
    name  = "vpcId"
    value = module.networking.vpc_id
  }

  depends_on = [
    module.compute,
    kubernetes_service_account.aws_lbc
  ]
}
