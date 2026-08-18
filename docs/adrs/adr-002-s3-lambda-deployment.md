# ADR 002 — S3-Based Lambda Deployment over Inline Archive

**Date:** 2026-08-04  
**Status:** Accepted  

## Context

Terraform needs to package and deploy three Lambda functions (producer, processor,
notifier). Terraform's `aws_lambda_function` resource supports deploying code either
directly as a local ZIP (`filename` argument) or via an S3 object (`s3_bucket` +
`s3_key`). A decision was needed on which deployment path to use before writing
`lambda.tf`.

## Decision

Package each Lambda's source directory into a ZIP using the `archive_file` data
source, upload the ZIP to a dedicated S3 bucket (`aws_s3_object`), and reference
the S3 object from `aws_lambda_function` via `s3_bucket` / `s3_key`, with
`source_code_hash` tracking the archive's hash so Terraform redeploys only when
the code actually changes.

## Alternatives Considered

**1. Inline deployment via `filename` argument (no S3)**  
Terraform would upload the ZIP directly to Lambda without an intermediate S3 step.
Simpler — one fewer resource type, no bucket to manage. Rejected because this is
not how Lambda deployment works in most real environments: CI/CD pipelines package
build artifacts and stage them in S3 (or ECR for containers) before deployment,
separately from the infrastructure-apply step. Using `filename` directly also means
Terraform re-reads and re-uploads the full ZIP contents on every plan, rather than
comparing against a stored artifact.

**2. Container image deployment (Lambda on ECR)**  
Lambda supports container images as an alternative to ZIP packages. Rejected for
this project specifically — these are small, dependency-free Python functions
(stdlib + boto3, which is already available in the Lambda runtime), so a ZIP is
simpler and faster to deploy. Container images would be justified if a function
needed custom system dependencies or a larger runtime footprint. This tradeoff was
already explored explicitly in `aws-ecs-url-shortener` (ECS Fargate + Docker/ECR).

## Consequences

**Positive:**
- Matches real-world CI/CD patterns: build artifact → object storage → deploy
  reference, rather than infra tooling embedding the artifact directly
- `source_code_hash` (from `archive_file.output_base64sha256`) gives Terraform a
  reliable way to detect code changes without relying on S3 object metadata timing
- S3 bucket versioning (enabled on `lambda_artifacts`) provides a rollback path —
  previous ZIP versions remain retrievable even after a new deploy overwrites the key

**Negative:**
- One extra resource per function (`aws_s3_object`) and one extra bucket to manage
  and eventually empty before `terraform destroy`
- Local ZIP files are generated as a side effect (`lambdas/*.zip`) and must be
  explicitly gitignored — they are build artifacts, not source
