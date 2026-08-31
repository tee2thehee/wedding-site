# OIDC curriculum step. AWS only allows one provider per URL per account,
# so this just references it and adds a role scoped to wedding-site.
 
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
 
resource "aws_iam_role" "github_actions_wedding_site" {
  name = "github-actions-wedding-site-deploy"
 
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:tee2thehee/wedding-site:ref:refs/heads/main"
        }
      }
    }]
  })
}
 
resource "aws_iam_role_policy" "github_actions_wedding_site" {
  name = "wedding-site-deploy-permissions"
  role = aws_iam_role.github_actions_wedding_site.id
 
  # Swap the two hardcoded values below for references to your actual
  # aws_s3_bucket / aws_cloudfront_distribution resources in main.tf if
  # you'd rather not hardcode (e.g. aws_s3_bucket.site.arn).
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::tncherry-com-site"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::tncherry-com-site/*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = "arn:aws:cloudfront::164761934758:distribution/ERZBI1CBZWSZV"
      }
    ]
  })
}
 
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_wedding_site.arn
}
 