#!/bin/bash

# GitHub Repository Setup Script for CEA Commerce Jenkins Pipeline
# This script helps set up the GitHub repository with all necessary configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if required tools are installed
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install Git first."
    fi
    
    if ! command -v gh &> /dev/null; then
        warn "GitHub CLI (gh) is not installed. Some features will be limited."
        warn "Install GitHub CLI from: https://cli.github.com/"
        USE_GH_CLI=false
    else
        USE_GH_CLI=true
    fi
    
    log "Prerequisites check completed"
}

# Initialize Git repository if not already initialized
init_git_repo() {
    if [ ! -d ".git" ]; then
        log "Initializing Git repository..."
        git init
        git add .
        git commit -m "Initial commit: CEA Commerce Jenkins Pipeline setup"
    else
        log "Git repository already initialized"
    fi
}

# Create GitHub repository
create_github_repo() {
    if [ "$USE_GH_CLI" = true ]; then
        log "Creating GitHub repository..."
        
        read -p "Enter repository name (default: cea-commerce-deployment): " REPO_NAME
        REPO_NAME=${REPO_NAME:-cea-commerce-deployment}
        
        read -p "Enter repository description (default: CEA Commerce Jenkins Pipeline for AWS EC2 Deployment): " REPO_DESC
        REPO_DESC=${REPO_DESC:-"CEA Commerce Jenkins Pipeline for AWS EC2 Deployment"}
        
        read -p "Make repository private? (y/N): " PRIVATE_REPO
        if [[ $PRIVATE_REPO =~ ^[Yy]$ ]]; then
            VISIBILITY="--private"
        else
            VISIBILITY="--public"
        fi
        
        gh repo create "$REPO_NAME" $VISIBILITY --description "$REPO_DESC" --source .
        
        log "GitHub repository created successfully"
    else
        info "Please create a GitHub repository manually at https://github.com/new"
        info "Repository name suggestion: cea-commerce-deployment"
        info "Then add the remote origin:"
        info "git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
        
        read -p "Press Enter after creating the repository and adding remote origin..."
    fi
}

# Set up GitHub secrets
setup_github_secrets() {
    log "Setting up GitHub secrets..."
    
    if [ "$USE_GH_CLI" = true ]; then
        info "Please provide the following information for GitHub secrets:"
        
        read -p "Jenkins URL (e.g., https://jenkins.company.com): " JENKINS_URL
        read -p "Jenkins Username: " JENKINS_USER
        read -s -p "Jenkins API Token: " JENKINS_TOKEN
        echo
        
        # Set secrets using GitHub CLI
        echo "$JENKINS_URL" | gh secret set JENKINS_URL
        echo "$JENKINS_USER" | gh secret set JENKINS_USER
        echo "$JENKINS_TOKEN" | gh secret set JENKINS_TOKEN
        
        log "GitHub secrets configured successfully"
    else
        info "Please manually add the following secrets to your GitHub repository:"
        info "Go to: Repository Settings > Secrets and variables > Actions > New repository secret"
        echo
        info "Required secrets:"
        info "1. JENKINS_URL - Your Jenkins server URL (e.g., https://jenkins.company.com)"
        info "2. JENKINS_USER - Jenkins username"
        info "3. JENKINS_TOKEN - Jenkins API token"
        echo
        info "To generate Jenkins API token:"
        info "1. Login to Jenkins"
        info "2. Go to: User Menu > Configure > API Token > Add new Token"
        info "3. Copy the generated token"
    fi
}

# Set up branch protection rules
setup_branch_protection() {
    if [ "$USE_GH_CLI" = true ]; then
        log "Setting up branch protection rules..."
        
        # Protect main branch
        gh api repos/:owner/:repo/branches/main/protection \
            --method PUT \
            --field required_status_checks='{"strict":true,"contexts":[]}' \
            --field enforce_admins=true \
            --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
            --field restrictions=null \
            2>/dev/null || warn "Could not set up branch protection (may require admin permissions)"
        
        log "Branch protection rules configured"
    else
        info "Please manually set up branch protection rules:"
        info "Go to: Repository Settings > Branches > Add rule"
        info "Branch name pattern: main"
        info "Enable: Require pull request reviews before merging"
        info "Enable: Require status checks to pass before merging"
    fi
}

# Create environment-specific branches
create_branches() {
    log "Creating environment-specific branches..."
    
    # Create develop branch
    if ! git show-ref --verify --quiet refs/heads/develop; then
        git checkout -b develop
        git push -u origin develop
        log "Created develop branch"
    else
        log "develop branch already exists"
    fi
    
    # Create release branch example
    if ! git show-ref --verify --quiet refs/heads/release/v1.0; then
        git checkout -b release/v1.0
        git push -u origin release/v1.0
        log "Created release/v1.0 branch"
    else
        log "release/v1.0 branch already exists"
    fi
    
    # Switch back to main
    git checkout main
}

# Set up GitHub environments
setup_github_environments() {
    if [ "$USE_GH_CLI" = true ]; then
        log "Setting up GitHub environments..."
        
        # Create environments
        for env in dev staging prod; do
            gh api repos/:owner/:repo/environments/$env --method PUT \
                --field wait_timer=0 \
                --field reviewers='[]' \
                --field deployment_branch_policy='{"protected_branches":false,"custom_branch_policies":true}' \
                2>/dev/null || warn "Could not create $env environment"
        done
        
        log "GitHub environments configured"
    else
        info "Please manually set up GitHub environments:"
        info "Go to: Repository Settings > Environments"
        info "Create environments: dev, staging, prod"
    fi
}

# Update configuration files with user input
update_config_files() {
    log "Updating configuration files..."
    
    read -p "Enter your AWS region (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    read -p "Enter your Commerce Suite download URL: " COMMERCE_URL
    read -p "Enter your Git repository URL: " GIT_REPO_URL
    read -p "Enter your EC2 instance IDs (comma-separated): " EC2_INSTANCES
    
    # Update Jenkinsfile
    if [ -f "Jenkinsfile" ]; then
        sed -i.bak "s|AWS_DEFAULT_REGION = 'us-east-1'|AWS_DEFAULT_REGION = '$AWS_REGION'|g" Jenkinsfile
        sed -i.bak "s|COMMERCE_SUITE_URL = 'https://your-artifact-repo/Commerce-suite-2211.FP6.240510019.zip'|COMMERCE_SUITE_URL = '$COMMERCE_URL'|g" Jenkinsfile
        sed -i.bak "s|GIT_REPO_URL = 'https://github.com/your-org/your-commerce-repo.git'|GIT_REPO_URL = '$GIT_REPO_URL'|g" Jenkinsfile
        sed -i.bak "s|EC2_INSTANCE_IDS = 'i-1234567890abcdef0,i-0987654321fedcba0'|EC2_INSTANCE_IDS = '$EC2_INSTANCES'|g" Jenkinsfile
        rm -f Jenkinsfile.bak
        log "Updated Jenkinsfile with your configuration"
    fi
    
    # Update deployment-config.yaml
    if [ -f "deployment-config.yaml" ]; then
        sed -i.bak "s|us-east-1|$AWS_REGION|g" deployment-config.yaml
        rm -f deployment-config.yaml.bak
        log "Updated deployment-config.yaml with your AWS region"
    fi
}

# Generate Jenkins job configuration
generate_jenkins_job_config() {
    log "Generating Jenkins job configuration..."
    
    cat > jenkins-job-config.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobAction plugin="pipeline-model-definition@1.8.5"/>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction plugin="pipeline-model-definition@1.8.5">
      <jobProperties/>
      <triggers/>
      <parameters/>
      <options/>
    </org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction>
  </actions>
  <description>CEA Commerce deployment pipeline for AWS EC2 instances</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.plugins.jira.JiraProjectProperty plugin="jira@3.7"/>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <com.cloudbees.jenkins.GitHubPushTrigger plugin="github@1.34.1">
          <spec></spec>
        </com.cloudbees.jenkins.GitHubPushTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>DEPLOYMENT_ENVIRONMENT</name>
          <description>Select deployment environment</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>dev</string>
              <string>staging</string>
              <string>prod</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>SKIP_TESTS</name>
          <description>Skip running tests</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>GIT_BRANCH</name>
          <description>Git branch to deploy</description>
          <defaultValue>main</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.92">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.8.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>REPLACE_WITH_YOUR_REPO_URL</url>
          <credentialsId>github-credentials</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
    
    log "Generated jenkins-job-config.xml"
    info "Import this file into Jenkins to create the job"
}

# Create documentation
create_setup_documentation() {
    log "Creating setup documentation..."
    
    cat > SETUP.md << 'EOF'
# CEA Commerce GitHub Setup Guide

This guide walks you through setting up the GitHub repository for automated CEA Commerce deployments with Jenkins.

## 📋 Prerequisites

- Git installed
- GitHub account
- GitHub CLI (optional but recommended)
- Jenkins server with required plugins
- AWS account and EC2 instances

## 🚀 Quick Setup

1. **Run the setup script:**
   ```bash
   ./scripts/github-setup.sh
   ```

2. **Follow the prompts to:**
   - Create GitHub repository
   - Configure secrets
   - Set up branch protection
   - Create environment branches

## 🔧 Manual Setup Steps

If you prefer manual setup or the script fails:

### 1. Create GitHub Repository

1. Go to [GitHub](https://github.com/new)
2. Create a new repository named `cea-commerce-deployment`
3. Choose public or private based on your needs
4. Don't initialize with README (we already have files)

### 2. Add Remote and Push

```bash
git remote add origin https://github.com/YOUR_USERNAME/cea-commerce-deployment.git
git branch -M main
git push -u origin main
```

### 3. Configure GitHub Secrets

Go to Repository Settings > Secrets and variables > Actions

Add these secrets:
- `JENKINS_URL`: Your Jenkins server URL
- `JENKINS_USER`: Jenkins username  
- `JENKINS_TOKEN`: Jenkins API token

### 4. Set Up Jenkins Job

1. Import `jenkins-job-config.xml` into Jenkins
2. Update the Git repository URL
3. Configure AWS and SSH credentials in Jenkins

### 5. Create Branches

```bash
git checkout -b develop
git push -u origin develop

git checkout -b release/v1.0
git push -u origin release/v1.0

git checkout main
```

## 🌟 Automated Deployment Triggers

The pipeline will automatically trigger on:

- **Push to `main`**: Deploys to production
- **Push to `develop`**: Deploys to development
- **Push to `release/*`**: Deploys to staging
- **Manual dispatch**: Deploy any branch to any environment

## 📚 Next Steps

1. Update configuration files with your specific values
2. Test the pipeline with a small change
3. Monitor deployments in Jenkins
4. Set up additional environments if needed

## 🆘 Troubleshooting

- Check GitHub Actions logs for trigger issues
- Verify Jenkins credentials and connectivity
- Ensure EC2 instances are properly configured
- Review AWS permissions and security groups

For more details, see the main README.md file.
EOF
    
    log "Created SETUP.md documentation"
}

# Main execution
main() {
    log "Starting GitHub repository setup for CEA Commerce Jenkins Pipeline"
    
    check_prerequisites
    init_git_repo
    
    read -p "Do you want to create a new GitHub repository? (y/N): " CREATE_REPO
    if [[ $CREATE_REPO =~ ^[Yy]$ ]]; then
        create_github_repo
        setup_github_secrets
        setup_github_environments
        setup_branch_protection
        create_branches
    fi
    
    read -p "Do you want to update configuration files with your values? (y/N): " UPDATE_CONFIG
    if [[ $UPDATE_CONFIG =~ ^[Yy]$ ]]; then
        update_config_files
    fi
    
    generate_jenkins_job_config
    create_setup_documentation
    
    # Final commit and push
    git add .
    git commit -m "Complete GitHub setup for CEA Commerce deployment" || true
    git push origin main || warn "Could not push to remote. Please push manually."
    
    log "✅ GitHub repository setup completed successfully!"
    
    echo
    info "📝 Next Steps:"
    echo "1. Review and update configuration files"
    echo "2. Import jenkins-job-config.xml into Jenkins"
    echo "3. Configure Jenkins credentials (AWS, SSH, GitHub)"
    echo "4. Test the pipeline with a small change"
    echo "5. Review SETUP.md for detailed instructions"
    
    echo
    info "🔗 Useful Links:"
    echo "- Repository: $(git config --get remote.origin.url 2>/dev/null || echo 'Not configured')"
    echo "- Actions: $(git config --get remote.origin.url 2>/dev/null | sed 's/\.git$/\/actions/' || echo 'Not configured')"
    echo "- Settings: $(git config --get remote.origin.url 2>/dev/null | sed 's/\.git$/\/settings/' || echo 'Not configured')"
}

# Run main function
main "$@"