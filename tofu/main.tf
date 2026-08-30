terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ACM certs used by CloudFront must be requested in us-east-1, no matter
# where the rest of your resources live.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Reads the API token from the CLOUDFLARE_API_TOKEN environment variable —
# never hardcode it here.
provider "cloudflare" {}

# Cloudflare is the domain's real, permanent DNS host (it can't be delegated
# away to Route 53 — Cloudflare Registrar doesn't allow custom nameservers).
# So we look up the zone Cloudflare already created when the domain was
# registered, rather than creating a Route 53 zone.
data "cloudflare_zone" "site" {
  filter = {
    name = var.domain_name
  }
}

locals {
  bucket_name = "${replace(var.domain_name, ".", "-")}-site"
}

# ---------------------------------------------------------------------------
# S3 — private bucket, only reachable through CloudFront
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# ACM certificate (DNS-validated via a record in Cloudflare)
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "site" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_dns_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name    = trimsuffix(dvo.resource_record_name, ".${var.domain_name}.")
      content = trimsuffix(dvo.resource_record_value, ".")
      type    = dvo.resource_record_type
    }
  }
  zone_id = data.cloudflare_zone.site.zone_id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  ttl     = 60
  proxied = false
  comment = "ACM certificate validation"
}

resource "aws_acm_certificate_validation" "site" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.site.arn
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.site.domain_validation_options :
    trimsuffix(dvo.resource_record_name, ".")
  ]
  depends_on = [cloudflare_dns_record.cert_validation]
}

# ---------------------------------------------------------------------------
# CloudFront — private S3 origin via Origin Access Control
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # US/Canada/Europe + Asia/Middle East/Africa (includes real edge locations
  # in Hanoi and Ho Chi Minh City) — covers both US and Vietnam guests.
  price_class = "PriceClass_200"
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
        }
      }
    }]
  })
}

# ---------------------------------------------------------------------------
# Cloudflare — records pointing the domain at CloudFront
# ---------------------------------------------------------------------------
resource "cloudflare_dns_record" "apex" {
  zone_id = data.cloudflare_zone.site.zone_id
  name    = "@"
  content = aws_cloudfront_distribution.site.domain_name
  type    = "CNAME"
  ttl     = 300
  proxied = false
  comment = "Apex -> CloudFront (Cloudflare flattens this automatically)"
}

resource "cloudflare_dns_record" "www" {
  zone_id = data.cloudflare_zone.site.zone_id
  name    = "www"
  content = aws_cloudfront_distribution.site.domain_name
  type    = "CNAME"
  ttl     = 300
  proxied = false
}
