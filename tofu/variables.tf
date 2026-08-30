variable "aws_region" {
  description = "Region for the S3 bucket. CloudFront itself is global; the ACM cert always goes to us-east-1 separately regardless of this setting."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Your registered apex domain, e.g. tncherry.com. A Route 53 hosted zone for it is created by this stack, not assumed to exist."
  type        = string
}