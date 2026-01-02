# Single Account Setup Alternatives

This guide provides two alternatives to the cross-account setup described in README.md:

1. **Single Account Role Assumption** - Learn the assume-role pattern within one account
2. **AWS Organizations Multi-Account Setup** - Create a proper multi-account structure for the cross-account scenario

---

## Option 1: Single Account Role Assumption

This approach creates a role in the same AWS account that your IAM user can assume. While it doesn't demonstrate cross-account access, it teaches the role assumption pattern.

### Prerequisites

1. **AWS CLI configured** with a single profile
2. **Terraform** installed (version >= 1.0)
3. **Administrative access** to your AWS account
4. **Existing IAM user** or use your current user

### Configuration Changes

You'll need to modify the Terraform files to work with a single account:

#### 1. Update `main.tf`

Change the provider aliases to use the same account:

```hcl
# Configure the primary AWS provider
provider "aws" {
  alias   = "primary"
  profile = "sopes-saloon"  # Your single AWS profile
}

# Configure the "secondary" provider pointing to the same account
provider "aws" {
  alias   = "secondary"
  profile = "sopes-saloon"  # Same profile as primary
}
```

#### 2. Update `secondary-account.tf`

Change the trust policy to trust the same account:

```hcl
data "aws_caller_identity" "primary" {
  provider = aws.primary
}

resource "aws_iam_role" "cross_account_role" {
  provider = aws.secondary
  name     = var.cross_account_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.primary.account_id  # Same account
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
```

### Deployment

1. **Configure AWS CLI:**
   ```bash
   aws configure --profile "sopes-saloon"
   ```

2. **Copy and edit variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   Edit `terraform.tfvars`:
   ```hcl
   cross_account_role_name = "S3BucketManagementRole"
   primary_user_name       = "your-iam-username"
   ```

3. **Initialize and apply:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Test role assumption:**
   ```bash
   aws sts assume-role \
     --role-arn "arn:aws:iam::YOUR_ACCOUNT_ID:role/S3BucketManagementRole" \
     --role-session-name "test-session" \
     --profile sopes-saloon
   ```

### Limitations

- Doesn't demonstrate true account isolation
- Less realistic for enterprise scenarios
- Still useful for learning STS and role assumption mechanics

---

## Option 2: AWS Organizations Multi-Account Setup

This approach creates a proper multi-account structure using AWS Organizations, which is the recommended way to manage multiple AWS accounts.

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

#### Step 3: Configure AWS CLI Profiles

After account creation, set up profiles for both accounts:

**Primary Account (Management Account):**
```bash
aws configure --profile sopes-saloon
# Enter your existing access keys
```

**Secondary Account (via Role Assumption):**

Create/edit `~/.aws/config` (Linux/Mac) or `%USERPROFILE%\.aws\config` (Windows):

```ini
[profile sopes-saloon]
region = us-west-2
output = json

[profile security]
region = us-west-2
role_arn = arn:aws:iam::SECONDARY_ACCOUNT_ID:role/OrganizationAccountAccessRole
source_profile = sopes-saloon
```

**To find the secondary account ID:**
```bash
aws organizations list-accounts --profile sopes-saloon
```

#### Step 4: Test Access to Secondary Account

```bash
# Test that you can access the secondary account
aws sts get-caller-identity --profile security
```

You should see the secondary account ID in the response.

#### Step 5: Update Terraform Configuration

Now you can use the original README.md configuration with these profiles:

1. **Keep `main.tf` as-is:**
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

2. **Deploy the infrastructure:**
   ```bash
   cd aws_setup
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your user details
   terraform init
   terraform plan
   terraform apply
   ```

### Email Alias Tips

Most email providers support aliases:

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

If you want to remove the secondary account:

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

## Recommendations

- **Just learning Terraform?** → Use Single Account approach
- **Learning AWS architecture patterns?** → Use AWS Organizations
- **Planning to use AWS professionally?** → Definitely use AWS Organizations
- **Working on this course/tutorial?** → Check what the course expects

---

## Additional Resources

- [AWS Organizations Documentation](https://docs.aws.amazon.com/organizations/)
- [AWS Multi-Account Best Practices](https://aws.amazon.com/organizations/getting-started/best-practices/)
- [IAM Role Assumption Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html)
- [AWS Landing Zone](https://aws.amazon.com/solutions/implementations/aws-landing-zone/)
