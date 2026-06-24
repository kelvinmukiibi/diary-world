# AWS Setup for Diary World Version 2.0

The infrastructure in `aws/template.yaml` uses AWS SAM to deploy:

`Flutter app → Cognito → API Gateway → Lambda → presigned URL → private S3`

Lambda writes safe operational events to CloudWatch Logs. Diary content is
uploaded directly to S3 only after client-side encryption.

## 1. Create or secure your AWS account manually

AWS account creation requires your identity, email/phone verification, and a
payment method, so it is intentionally not automated here.

1. Create or sign in to your own AWS account at <https://aws.amazon.com/>.
2. Enable multi-factor authentication on the root user.
3. Do **not** use root credentials for development or daily administration.
4. Create an administrative IAM Identity Center user for initial deployment,
   then use short-lived SSO credentials (`aws configure sso`).
5. Enable a small AWS Budget and billing alerts before deploying.
6. Never paste AWS keys into Flutter, Git, documentation, chat, or source files.

For a team or production environment, have an AWS administrator create a
least-privilege deployment role restricted to CloudFormation/SAM resources in
this stack. The runtime Lambda role in the template can only write objects under
the bucket's `backups/` prefix; it cannot list, read, or delete backups.

## 2. Install and authenticate tools

Install the AWS CLI and AWS SAM CLI, then authenticate with SSO or another
short-lived credential method:

```powershell
aws configure sso
aws sts get-caller-identity
sam --version
```

Do not use `aws configure` with long-lived root access keys.

## 3. Validate and deploy

From the repository root:

```powershell
cd aws
sam validate --lint
sam build
sam deploy --guided
```

Suggested guided-deployment answers:

- Stack name: `diary-world-v2-backup`
- Region: choose the region appropriate for your data-residency needs
- Confirm changes before deploy: `Y`
- Allow SAM to create IAM roles: `Y`
- Save arguments to `samconfig.toml`: optional; the file is ignored

The template defaults to 10-minute presigned URLs. You may choose 300–900
seconds. It accepts encrypted JSON backup envelopes up to 25 MB by default.
API Gateway rejects requests without a valid, unexpired Cognito ID token.

After deployment, retrieve all client configuration outputs:

```powershell
aws cloudformation describe-stacks `
  --stack-name diary-world-v2-backup `
  --query "Stacks[0].Outputs[].[OutputKey,OutputValue]" `
  --output table
```

Put the HTTPS endpoint, Cognito region, and Cognito client ID in the ignored
`config/aws_backup.json` file, using `config/aws_backup.example.json` as the
shape. The client ID is intentionally created without a client secret.

### Create a proof-of-concept backup user

In the AWS console, open **Cognito → User pools → the deployed pool → Users**,
then create a test user and set a permanent password that satisfies the policy.
Avoid putting the password in shell commands, source files, screenshots, or
PowerShell history. The app asks for these credentials only when the user starts
a backup and keeps the resulting one-hour ID token in memory only.

## 4. Verify security controls

```powershell
aws cloudformation describe-stacks --stack-name diary-world-v2-backup
aws s3api get-public-access-block --bucket YOUR_DEPLOYED_BUCKET_NAME
aws s3api get-bucket-encryption --bucket YOUR_DEPLOYED_BUCKET_NAME
aws s3api get-bucket-versioning --bucket YOUR_DEPLOYED_BUCKET_NAME
```

In the AWS console, also verify:

- S3 **Block all public access** is enabled.
- Default encryption is SSE-S3 (AES-256).
- The Lambda execution role has only `s3:PutObject` on `backups/*`, plus its
  AWS-managed basic logging permissions.
- API Gateway has the Cognito authorizer enabled and unauthenticated calls
  return `401 Unauthorized`.
- Uploaded objects include an S3-validated SHA-256 checksum.
- Lambda log retention is 30 days and logs contain no request body or diary
  content.
- API Gateway and Lambda X-Ray tracing is appropriate for your privacy policy.

## 5. Optional KMS upgrade

The proof of concept uses AES-256 SSE-S3 to avoid managing a KMS key. For
production, create a customer-managed KMS key, change the bucket encryption and
presigned upload parameters to `aws:kms`, and grant the Lambda role only the
necessary `kms:GenerateDataKey` permissions for that key. Configure key
rotation and an explicit key policy. Do not put the KMS key ARN into Flutter.

## 6. CloudWatch troubleshooting

Open CloudWatch Logs and select the log group named after the presign Lambda.
Only request ID, accepted encrypted size, expiry, and validation outcome should
appear. Never add logging of `event`, request bodies, presigned URLs, S3 object
contents, passphrases, or audio.

## 7. Remove the proof of concept

```powershell
sam delete --stack-name diary-world-v2-backup
```

The S3 bucket and Lambda log group use `Retain` to protect data from accidental
stack deletion. Empty and delete those resources manually only after confirming
that no backup or audit data must be preserved.
