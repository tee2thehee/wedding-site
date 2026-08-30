# Game Plan

Static wedding invite site on our own domain (S3 + CloudFront + Route 53 +
ACM, deployed via GitHub Actions), with WedUploader handling the guest photo
QR flow externally (linked from the site, not hosted by us).

## Steps

1. **Register the domain.** Route 53 directly, or another registrar with DNS
   delegated to a Route 53 hosted zone. Everything below depends on this.
2. **Set up WedUploader.** Google Sign-In on the account that should own the
   Drive, create the album, pay the one-time ~$39 for Limitless (real-time
   gallery, QR code, personalized link).
3. **Push this repo to GitHub.** Already git-initialized locally; just needs
   a remote and a push. Repo: `tee2thehee/tncherry`.
4. **Provision AWS infra.** `tofu apply` from `tofu/` with our domain, using
   our own AWS credentials, run locally (never through Claude). Takes 15–20
   min for CloudFront to deploy. (Using OpenTofu, not Terraform — same HCL,
   drop-in compatible, no code changes needed.)
5. **Wire up GitHub Actions.** Deploy-only IAM user scoped to just this
   bucket + distribution; its keys, bucket name, and distribution ID go in
   as GitHub repo secrets. From here, `git push` auto-deploys.
6. **Connect the two.** Real WedUploader link into `site/index.html`, push,
   confirm the domain loads over HTTPS and the photo link/QR works.
7. **Design pass — deferred until the domain is live.** Also the point to
   decide how real content (names, date, exact venue/address) gets into the
   site — see note below on public repo + personal info.
8. **Wedding weekend (Dec 19–20) + wrap-up.** Print/display the WedUploader
   QR. No AWS teardown needed after — static site + external WedUploader
   link, nothing running that costs money or needs to be shut off.

## Repo visibility

Public. The code itself is safe to share: no secrets are ever committed
(AWS/deploy keys live only in GitHub Actions secrets), and the Terraform
doesn't hardcode the domain or account ID — the domain is passed with
`-var` at apply time, and outputs (bucket name, distribution ID) are printed
to the terminal, never written into the repo.

The one thing to watch: once real content (names, exact date, venue
address) goes into `site/index.html` and gets committed, it's permanently in
git history and publicly searchable — a different exposure than just "on
our wedding website," since it's now indexed and tied to our names on
GitHub specifically, forever, even if later edited. At step 7, worth
templating that content in from a gitignored file or GitHub Actions
repository variables (a small `envsubst` step in the deploy workflow) rather
than hardcoding it, so the public repo shows the actual engineering
(interview-relevant) while the personal details never enter git history at
all. Flagged here so we don't forget it once we get to step 7.

## Domain

`tncherry.com`, registered via Cloudflare Registrar ($10.46/yr), DNS
delegated to a Route 53 hosted zone (registrar and DNS host don't have to
match — see step 4).
