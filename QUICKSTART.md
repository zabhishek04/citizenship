# 🚀 CEA Commerce GitHub + Jenkins Quick Start Guide

This guide will get you up and running with automated CEA Commerce deployments from GitHub to AWS EC2 instances via Jenkins in under 30 minutes.

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] **GitHub Account** with repository access
- [ ] **Jenkins Server** running and accessible
- [ ] **AWS Account** with EC2 instances
- [ ] **Git** installed locally
- [ ] **GitHub CLI** (optional but recommended)

## 🎯 Quick Setup (5 Steps)

### Step 1: Clone and Setup Repository

```bash
# Clone this repository or copy all files to your project
git clone https://github.com/your-org/cea-commerce-deployment.git
cd cea-commerce-deployment

# Run the automated setup script
./scripts/github-setup.sh
```

### Step 2: Configure Your Environment

Update these files with your specific values:

#### `Jenkinsfile` (Required Changes):
```groovy
environment {
    AWS_DEFAULT_REGION = 'your-aws-region'                    // e.g., 'us-east-1'
    COMMERCE_SUITE_URL = 'your-commerce-suite-download-url'   // Commerce ZIP URL
    GIT_REPO_URL = 'your-github-repo-url'                     // This repository
    EC2_INSTANCE_IDS = 'i-abc123,i-def456'                    // Your EC2 instances
}
```

#### `deployment-config.yaml` (Optional):
```yaml
environments:
  dev:
    ec2_instances:
      - "your-dev-instance-id"
  prod:
    ec2_instances:
      - "your-prod-instance-1"
      - "your-prod-instance-2"
```

### Step 3: Setup EC2 Instances

Run this on each EC2 instance:

```bash
# Copy the setup script to your EC2 instances
scp -i your-key.pem setup-ec2-instance.sh ec2-user@your-instance-ip:~/

# SSH to each instance and run
ssh -i your-key.pem ec2-user@your-instance-ip
chmod +x setup-ec2-instance.sh
./setup-ec2-instance.sh
```

### Step 4: Configure Jenkins

#### A. Install Required Plugins

In Jenkins, go to **Manage Jenkins > Manage Plugins** and install:
- AWS Pipeline Plugin
- SSH Agent Plugin
- GitHub Plugin
- Email Extension Plugin

#### B. Add Credentials

Go to **Manage Jenkins > Manage Credentials** and add:

1. **AWS Credentials** (ID: `aws-credentials`)
   - Kind: AWS Credentials
   - Access Key ID: Your AWS access key
   - Secret Access Key: Your AWS secret key

2. **SSH Private Key** (ID: `ec2-keypair`)
   - Kind: SSH Username with private key
   - Username: `ec2-user`
   - Private Key: Your EC2 key pair private key

3. **GitHub Credentials** (ID: `github-credentials`)
   - Kind: Username with password
   - Username: Your GitHub username
   - Password: Your GitHub personal access token

#### C. Create Jenkins Job

1. Import the job configuration:
   - Go to Jenkins Dashboard
   - Click "New Item"
   - Enter name: `CEA-Commerce-Deployment`
   - Select "Pipeline"
   - In configuration, select "Pipeline script from SCM"
   - Choose Git, enter your repository URL
   - Set credentials and branch (`*/main`)
   - Set script path: `Jenkinsfile`
   - Save

### Step 5: Configure GitHub Integration

#### A. Add GitHub Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions**:

```
JENKINS_URL=https://your-jenkins-server.com
JENKINS_USER=your-jenkins-username
JENKINS_TOKEN=your-jenkins-api-token
```

#### B. Test the Integration

```bash
# Make a test change
echo "# Test deployment" >> README.md
git add README.md
git commit -m "Test automated deployment"
git push origin main

# Check GitHub Actions tab for workflow execution
# Check Jenkins for triggered build
```

## 🌟 Deployment Workflow

Once setup is complete, deployments work automatically:

### Automatic Triggers

| Branch | Environment | Trigger |
|--------|-------------|---------|
| `main` | Production | Push to main |
| `develop` | Development | Push to develop |
| `release/*` | Staging | Push to release branch |

### Manual Triggers

1. Go to GitHub repository
2. Click **Actions** tab
3. Select **"Trigger Jenkins Deployment"**
4. Click **"Run workflow"**
5. Choose environment and parameters

## 📊 Monitoring Deployments

### GitHub

- **Actions Tab**: View workflow status
- **Deployments**: See deployment history
- **Pull Requests**: Automatic deployment comments

### Jenkins

- **Dashboard**: View build status
- **Build History**: Detailed logs
- **Blue Ocean**: Visual pipeline view

### EC2 Instances

```bash
# Check Hybris status
sudo systemctl status hybris

# View logs
tail -f /opt/CEASAP/cx/hybris/bin/platform/hybris.log

# Health check
/opt/CEASAP/health-check.sh
```

## 🔧 Common Configurations

### Environment-Specific Deployments

```bash
# Deploy specific branch to specific environment
curl -X POST \
  -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/job/CEA-Commerce-Deployment/buildWithParameters" \
  -d "DEPLOYMENT_ENVIRONMENT=staging" \
  -d "GIT_BRANCH=release/v1.0" \
  -d "SKIP_TESTS=false"
```

### Multiple Environment Setup

Create additional branches:

```bash
git checkout -b staging
git push -u origin staging

git checkout -b release/v1.0
git push -u origin release/v1.0
```

### Custom Deployment Parameters

Modify the `parameters` section in `Jenkinsfile`:

```groovy
parameters {
    choice(
        name: 'DEPLOYMENT_ENVIRONMENT',
        choices: ['dev', 'staging', 'prod', 'qa'],  // Add 'qa'
        description: 'Select deployment environment'
    )
    string(
        name: 'CUSTOM_CONFIG',
        defaultValue: '',
        description: 'Custom configuration parameter'
    )
}
```

## 🐛 Troubleshooting Quick Fixes

### Issue: GitHub Actions Not Triggering Jenkins

**Solution:**
```bash
# Test Jenkins API connectivity
curl -u username:token https://your-jenkins-server.com/api/json

# Check GitHub secrets are set correctly
# Verify Jenkins URL is accessible from GitHub
```

### Issue: EC2 Connection Failed

**Solution:**
```bash
# Test SSH connectivity
ssh -i your-key.pem ec2-user@your-instance-ip

# Check security groups allow SSH from Jenkins
# Verify EC2 instances are running
```

### Issue: Hybris Build Fails

**Solution:**
```bash
# Check Java version on EC2
java -version

# Verify JAVA_HOME is set
echo $JAVA_HOME

# Check disk space
df -h

# Review build logs
tail -f /opt/CEASAP/cx/hybris/bin/platform/hybris.log
```

### Issue: Load Balancer Not Updated

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify target group ARN
aws elbv2 describe-target-groups

# Check instance health
aws elbv2 describe-target-health --target-group-arn your-arn
```

## 🎯 Next Steps

After successful setup:

1. **Customize Pipeline**: Add additional stages for your specific needs
2. **Set Up Monitoring**: Configure CloudWatch, Datadog, or other monitoring
3. **Add Tests**: Integrate unit tests, integration tests, and security scans
4. **Documentation**: Document your specific configuration and processes
5. **Team Training**: Train your team on the new deployment process

## 📚 Additional Resources

- **Detailed Setup**: [SETUP.md](SETUP.md)
- **Jenkins Webhooks**: [jenkins-webhook-config.md](jenkins-webhook-config.md)
- **Main Documentation**: [README.md](README.md)
- **Configuration Reference**: [deployment-config.yaml](deployment-config.yaml)

## 🆘 Getting Help

If you encounter issues:

1. **Check Logs**: GitHub Actions, Jenkins console, EC2 system logs
2. **Verify Configuration**: Double-check all credentials and URLs
3. **Test Components**: Test each component individually
4. **Review Documentation**: Check the detailed guides for specific issues

## ✅ Success Checklist

Your deployment is working correctly when:

- [ ] GitHub push triggers Jenkins build
- [ ] Jenkins successfully connects to EC2 instances
- [ ] Commerce Suite downloads and extracts
- [ ] Hybris builds without errors
- [ ] Application starts and responds to health checks
- [ ] Load balancer shows healthy targets
- [ ] You can access the application

**🎉 Congratulations! Your automated CEA Commerce deployment pipeline is now ready!**