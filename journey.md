# The Journey - Troubleshooting

Errors hit while first provisioning this stack with OpenTofu, and how each
was resolved. Kept here since they're the kind of thing that'll happen again
on a fresh clone or after a provider upgrade.

## Cloudflare Registrar won't allow custom nameservers

**Symptom:** No "Nameservers" option anywhere in Cloudflare's domain
Settings page, even after creating a Route 53 hosted zone and getting its
4 nameserver values.

**Cause:** Domains registered through Cloudflare Registrar cannot be
delegated to a different DNS provider — this is a hard platform limitation,
not a missing setting. Confirmed via Cloudflare's own community forum.

**Fix:** Abandoned the Route 53 hosted zone approach. Cloudflare stays the
domain's real DNS; `main.tf` uses the `cloudflare` provider to create the
DNS records (ACM validation record, apex/www CNAMEs to CloudFront) directly
in Cloudflare's existing zone instead of Route 53. The already-created
`aws_route53_zone` resource was removed from code, letting `tofu` destroy
it on the next apply.

## `cloudflare_zone` data source: "Missing Attribute Configuration"

**Symptom:**



**Cause:** In Cloudflare's Terraform/OpenTofu provider v5, `data.cloudflare_zone`
no longer accepts a plain `name` argument — `name` is read-only (computed),
and the lookup has to go through a `filter` object instead.

**Fix:**
```hcl
data "cloudflare_zone" "site" {
  filter = {
    name = var.domain_name
  }
}
```

## Leftover output referencing a deleted resource

**Symptom:**



**Cause:** In Cloudflare's Terraform/OpenTofu provider v5, `data.cloudflare_zone`
no longer accepts a plain `name` argument — `name` is read-only (computed),
and the lookup has to go through a `filter` object instead.

**Fix:**
```hcl
data "cloudflare_zone" "site" {
  filter = {
    name = var.domain_name
  }
}
```

## Leftover output referencing a deleted resource

**Symptom:**


**Cause:** Every `cloudflare_dns_record` needs an explicit `ttl`, even
non-proxied ones — it's not optional the way it might be on other
providers.

**Fix:** Added `ttl = 300` to the `apex` and `www` records (the
`cert_validation` record already had `ttl = 60`).