# AWS Organizations Multi-Account Setup

This guide provides instructions for setting up a multi-account AWS environment using AWS Organizations. 

This approach creates a proper account structure that demonstrates cross-account IAM role assumption and is the recommended pattern for enterprise AWS environments.

### What is AWS Organizations?

AWS Organizations allows you to centrally manage multiple AWS accounts:
- **Consolidated billing** - Single bill for all accounts
- **Centralized management** - Manage accounts from one place
- **Service Control Policies** - Apply security policies across accounts
- **Easy account creation** - Create new accounts without separate billing

### Prerequisites

1. **Existing AWS account** (will become the management/root account)
2. **Additional email addresses** for new accounts (can use email aliases)
   - Example: `youremail+security@gmail.com`, `youremail+dev@gmail.com`
3. **Administrative access** to your current account

### Step-by-Step Setup

#### Step 1: Enable AWS Organizations

1. **Sign in to AWS Console** with your main account
2. **Navigate to AWS Organizations**:
   - Search for "Organizations" in the AWS Console
3. **Click "Create organization"**
4. **Choose "All features"** (not just consolidated billing)
5. **Verify your email** - AWS will send a verification email

#### Step 2: Create a Secondary Account

1. **In AWS Organizations console**, click **"Add an AWS account"**
2. **Select "Create an AWS account"**
3. **Fill in account details:**
   - **AWS account name**: `security-account` (or any descriptive name)
   - **Email address**: Must be unique - use an alias like `youremail+security@gmail.com`
   - **IAM role name**: `OrganizationAccountAccessRole` (default - keep this)
4. **Click "Create AWS account"**
5. **Wait for creation** (can take 5-10 minutes)

#### Step 3: Get the Secondary Account ID

After the account is created, you'll need its account ID for later steps.

**Bash:**
```bash
aws organizations list-accounts
```

**PowerShell:**
```powershell
aws organizations list-accounts
```

Look for your newly created `security-account` in the output and note the account ID (12-digit number).

#### Step 4: Authentication Options

You have two options for authenticating to AWS:

##### Option A: Using AWS Login (SSO) - Recommended if Already Using

If you're already using `aws login` (SSO authentication), you can continue with that approach. Your existing authentication will work for assuming roles in the secondary account.

**No configuration changes needed** - Terraform's `assume_role` block will automatically use your current credentials to assume the role in the secondary account. See Step 6 for details.

##### Option B: Using AWS Configure (Access Keys)

If you prefer to use access keys, configure profiles for both accounts:

**Bash:**
```bash
aws configure --profile sopes-saloon
# Enter your access key ID, secret key, region, and output format
```

**PowerShell:**
```powershell
aws configure --profile sopes-saloon
# Enter your access key ID, secret key, region, and output format
```

Then add a profile for the secondary account in `~/.aws/config` (Linux/Mac) or `%USERPROFILE%\.aws\config` (Windows):

```ini
[profile sopes-saloon]
region = us-west-2
output = json

[profile security]
region = us-west-2
role_arn = arn:aws:iam::SECONDARY_ACCOUNT_ID:role/OrganizationAccountAccessRole
source_profile = sopes-saloon
```

Replace `SECONDARY_ACCOUNT_ID` with the account ID from Step 3.

**If using aws login**, your config only needs the security profile (your default profile already exists):

```ini
[profile security]
region = us-west-2
role_arn = arn:aws:iam::SECONDARY_ACCOUNT_ID:role/OrganizationAccountAccessRole
source_profile = default
```

#### Step 5: Test Access to Secondary Account (Optional)

This step is optional but recommended to verify the role assumption works.

**Bash:**
```bash
# Test that you can access the secondary account
aws sts get-caller-identity --profile security
```

**PowerShell:**
```powershell
# Test that you can access the secondary account
aws sts get-caller-identity --profile security
```

You should see the secondary account ID in the response.

**Note:** If you're using aws login and didn't modify your config file, you can skip this test. Terraform will handle the role assumption automatically in the next step.

#### Step 6: Update Terraform Configuration

You have two options for configuring Terraform to use the secondary account:

##### Option A: Let Terraform Handle Role Assumption (Recommended for aws login users)

Update `aws_setup/main.tf` to use `assume_role` directly in the provider configuration:

```hcl
# Primary account provider
provider "aws" {
  alias  = "primary"
  region = "us-west-2"
}

# Secondary account provider with role assumption
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::SECONDARY_ACCOUNT_ID:role/OrganizationAccountAccessRole"
  }
}
```

Replace `SECONDARY_ACCOUNT_ID` with your actual secondary account ID.

This approach:
- Uses your current AWS credentials (from `aws login` or default profile)
- Automatically assumes the role when needed
- No config file modifications required
- Works with any authentication method

##### Option B: Use Named Profiles

If you set up profiles in Step 4 Option B, keep `aws_setup/main.tf` using profile references:

```hcl
provider "aws" {
  alias   = "primary"
  profile = "sopes-saloon"
}

provider "aws" {
  alias   = "secondary"
  profile = "security"
}
```

#### Step 7: Deploy the Infrastructure

**Bash:**
```bash
cd aws_setup
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your IAM user details
terraform init
terraform plan
terraform apply
```

**PowerShell:**
```powershell
cd aws_setup
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your IAM user details
terraform init
terraform plan
terraform apply
```

Edit `aws_setup/terraform.tfvars` with your details:
```hcl
cross_account_role_name = "S3BucketManagementRole"
primary_user_name       = "your-iam-username"
```

### Using the Cross-Account Role

After deployment, you can use the role in your other Terraform configurations (like `sopes_saloon/`).

The `aws_setup` configuration will output the role ARN. Use it in your `sopes_saloon/terraform.tfvars`:

```hcl
security_role_arn = "arn:aws:iam::SECONDARY_ACCOUNT_ID:role/S3BucketManagementRole"
```

Then in `sopes_saloon/providers.tf`, the provider will assume this role:

```hcl
provider "aws" {
  alias  = "security"
  region = var.region
  assume_role {
    role_arn = var.security_role_arn
  }
}
```

This allows resources in the sopes_saloon configuration to create resources in the secondary account.

### Email Alias Tips

Most email providers support aliases, allowing you to use one email address for multiple AWS accounts:

- **Gmail**: `yourname+security@gmail.com`, `yourname+dev@gmail.com`
- **Outlook**: `yourname+security@outlook.com`
- **Custom domains**: Usually support `+` addressing

All emails go to the same inbox, but AWS treats them as unique addresses.

### Cost Considerations

- **No additional cost** for creating accounts under Organizations
- **Consolidated billing** - All charges appear on one bill
- **Free tier applies per account** - Each account gets its own free tier eligibility
- You only pay for resources you actually create

### Organizational Structure Best Practices

Consider creating accounts for different purposes:

```
Root (Management Account - sopes-saloon)
├── security-account (Security tools, IAM roles, audit logs)
├── dev-account (Development workloads)
├── prod-account (Production workloads)
└── shared-services (DNS, monitoring, etc.)
```

### Managing Access

After setup, you can:

1. **Switch between accounts** using AWS CLI profiles
2. **Use the AWS Console** - Switch role feature to access secondary accounts
3. **Set up SSO** (AWS IAM Identity Center) for easier multi-account access

#### Switching Roles in AWS Console

1. **Click your username** in top-right corner
2. **Select "Switch Role"**
3. **Enter details:**
   - **Account**: Secondary account ID
   - **Role**: `OrganizationAccountAccessRole`
   - **Display Name**: `Security Account` (whatever you want)
   - **Color**: Choose a color to distinguish accounts
4. **Click "Switch Role"**

### Cleanup

If you want to remove the secondary account and all resources:

#### Step 1: Destroy Terraform Resources

First, destroy resources created by Terraform in both configurations:

**Bash:**
```bash
# Destroy sopes_saloon resources first (if deployed)
cd sopes_saloon
terraform destroy

# Then destroy aws_setup resources
cd ../aws_setup
terraform destroy
```

**PowerShell:**
```powershell
# Destroy sopes_saloon resources first (if deployed)
cd sopes_saloon
terraform destroy

# Then destroy aws_setup resources
cd ..\aws_setup
terraform destroy
```

#### Step 2: Close the Secondary Account

1. **Sign in to the secondary account** (switch role via console)
2. **Close the account**:
   - Go to Account Settings
   - Scroll to "Close Account"
   - Follow the prompts
3. **Remove from Organization**:
   - In management account, go to Organizations
   - Select the closed account
   - Choose "Remove account"

**Note**: Closed accounts can be reopened within 90 days if needed.

---

## Quick Reference

### Key Account IDs and ARNs

After setup, you'll have these important values:

- **Primary Account ID**: Your original AWS account (e.g., `654882306161`)
- **Secondary Account ID**: From Step 3 (e.g., `123456789012`)
- **Organization Role ARN**: `arn:aws:iam::SECONDARY_ACCOUNT_ID:role/OrganizationAccountAccessRole`
- **Cross-Account Role ARN**: `arn:aws:iam::SECONDARY_ACCOUNT_ID:role/S3BucketManagementRole`

### Common Commands

**List all accounts in organization:**

Bash:
```bash
aws organizations list-accounts
```

PowerShell:
```powershell
aws organizations list-accounts
```

**Test secondary account access:**

Bash:
```bash
aws sts get-caller-identity --profile security
```

PowerShell:
```powershell
aws sts get-caller-identity --profile security
```

**Or manually assume role:**

Bash:
```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::SECONDARY_ACCOUNT_ID:role/OrganizationAccountAccessRole" \
  --role-session-name "test-session"
```

PowerShell:
```powershell
aws sts assume-role `
  --role-arn "arn:aws:iam::SECONDARY_ACCOUNT_ID:role/OrganizationAccountAccessRole" `
  --role-session-name "test-session"
```

---

## Comparison: Single Account vs Organizations

| Feature | Single Account | AWS Organizations |
|---------|---------------|-------------------|
| **Setup Complexity** | Simple | Moderate |
| **Email Requirements** | One | One per account (use aliases) |
| **Cost** | Same as before | Same (consolidated billing) |
| **Realistic for Learning** | Basic role assumption | Enterprise pattern |
| **Account Isolation** | None (same account) | Full isolation |
| **Free Tier** | Single account limit | Per-account limits |
| **Best For** | Learning assume-role basics | Learning multi-account architecture |

---

## Troubleshooting

### "Access Denied" when assuming role

**Problem**: Cannot assume `OrganizationAccountAccessRole`

**Solutions**:
1. Verify the role exists in the secondary account
2. Check that your IAM user has permissions to assume roles
3. Confirm the account ID in the role ARN is correct
4. Ensure you're authenticated (run `aws sts get-caller-identity`)

### "Email address already in use"

**Problem**: Cannot create secondary account with email alias

**Solutions**:
1. Try a different alias (e.g., `+sec` instead of `+security`)
2. Use a completely different email address
3. Check if the email was used for a deleted account (wait 90 days or contact AWS support)

### Terraform can't find providers

**Problem**: `terraform init` fails with provider errors

**Solutions**:
1. Check your internet connection
2. Verify `~/.terraformrc` or `%APPDATA%\terraform.rc` doesn't have conflicting `provider_installation` blocks
3. Clear the plugin cache and try again

### Config file authentication issues

**Problem**: AWS CLI doesn't recognize profiles or role assumption fails

**Solutions**:
1. If using `aws login`, make sure you're authenticated: run `aws login` again
2. Verify the role ARN in your config matches the secondary account ID
3. Check that `source_profile` points to an authenticated profile
4. Try the Terraform `assume_role` approach instead (Option A in Step 6)

---

## Additional Resources

- [AWS Organizations Documentation](https://docs.aws.amazon.com/organizations/)
- [AWS Multi-Account Best Practices](https://aws.amazon.com/organizations/getting-started/best-practices/)
- [IAM Role Assumption Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html)
- [AWS Landing Zone](https://aws.amazon.com/solutions/implementations/aws-landing-zone/)
