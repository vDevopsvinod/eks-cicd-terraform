resource "aws_eks_cluster" "eks" {
  name     = "vinod-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  version = "1.28"

  vpc_config {
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "vinod-eks-cluster"
  }
}