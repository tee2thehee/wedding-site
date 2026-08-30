# Wedding Site

Static wedding landing page, hosted on your own domain via S3 + CloudFront,
deployed automatically from this repo via GitHub Actions.

## Stack

- **S3** — stores the built site files (kept private; never served directly)
- **CloudFront** — CDN in front of S3, handles HTTPS via ACM cert, this is what your domain actually points to
- **ACM** — free TLS certificate (must be requested in `us-east-1`, CloudFront requirement)
- **Route 53** — DNS: your domain's hosted zone, alias records pointing to CloudFront
- **OpenTofu** — defines all of the above as code, in `tofu/`
- **GitHub Actions** — on every push to `main` that touches `site/`, syncs files to S3 and invalidates the CloudFront cache

Why this instead of AWS Amplify Hosting: Amplify's free tier (build minutes,
storage, data transfer) only lasts 6 months after your AWS account is created,
then becomes pay-as-you-go with no free allowance. CloudFront's free tier
(1 TB transfer + 10M requests/month) is permanent, no expiration. For a site
you want to keep running indefinitely at near-zero traffic, this stack stays
free (or close to it — a couple dollars a year for the Route 53 hosted zone)
forever, where Amplify would start charging after month 6. You also get the
same git-push-to-deploy workflow either way, so you're not giving up any
convenience.

## One-time setup

### 1. Register your domain (if you haven't)

Buy it through Route 53, or through any registrar and then delegate DNS to
Route 53 (create a hosted zone for the domain, point the registrar's
nameservers at it). Either way, you need a Route 53 hosted zone for the
domain before running Terraform.

### 2. Install tools locally

- [OpenTofu](https://opentofu.org/docs/intro/install/) (>= 1.6)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), then run `aws configure` with your own credentials

Claude cannot run `tofu apply` for you — it needs your AWS credentials,
which should never be pasted into a chat. Run these steps yourself, locally.

### 3. Provision the infrastructure

```bash
cd tofu
tofu init
tofu apply -var="domain_name=tncherry.com"
```

This takes 15–20 minutes the first time (CloudFront distributions are slow to
deploy). When it finishes, note the two outputs:

```bash
tofu output
# s3_bucket        = "tncherry-com-site"
# cloudfront_domain = "d123abc456.cloudfront.net"
```

You'll also need the CloudFront distribution ID (not shown above) — get it
with:

```bash
aws cloudfront list-distributions --query "DistributionList.Items[?Aliases.Items[0]=='tncherry.com'].Id" --output text
```

### 4. Create a deploy-only IAM user

Least-privilege user for GitHub Actions to use — don't reuse your personal
AWS credentials here. Attach a policy scoped to just this bucket and
distribution (S3 read/write/delete on the bucket, `cloudfront:CreateInvalidation`
on the distribution), then generate an access key for it.

### 5. Add GitHub repo secrets

Settings → Secrets and variables → Actions, add:

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — from the deploy-only IAM user above
- `S3_BUCKET_NAME` — from `terraform output`
- `CLOUDFRONT_DISTRIBUTION_ID` — from the CLI command above

### 6. Push

```bash
git add .
git commit -m "Initial site"
git push origin main
```

GitHub Actions picks it up, syncs `site/` to S3, and invalidates the
CloudFront cache. Give it a minute or two, then check `https://yourdomain.com`.

## Day-to-day

Edit anything in `site/`, commit, push to `main` — it deploys itself. No need
to touch OpenTofu again unless you're changing infrastructure (e.g. adding a
new subdomain).

## Teardown (if you ever want to)

```bash
cd tofu
tofu destroy
```

Removes the S3 bucket, CloudFront distribution, ACM cert, and DNS records.
The domain registration itself is separate and won't be touched.
