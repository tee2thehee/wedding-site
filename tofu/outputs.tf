

output "s3_bucket" {
  description = "S3 bucket name — use as S3_BUCKET_NAME GitHub secret"
  value       = aws_s3_bucket.site.id
}

output "cloudfront_domain" {
  description = "CloudFront's own domain (useful for debugging before DNS propagates)"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  description = "Use as CLOUDFRONT_DISTRIBUTION_ID GitHub secret"
  value       = aws_cloudfront_distribution.site.id
}

