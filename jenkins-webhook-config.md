# Jenkins Webhook Configuration for GitHub Integration

This document provides step-by-step instructions for setting up automatic Jenkins pipeline triggers from GitHub.

## 🔗 Integration Methods

There are two main ways to integrate GitHub with Jenkins:

1. **GitHub Actions → Jenkins** (Recommended)
2. **GitHub Webhooks → Jenkins** (Direct)

## Method 1: GitHub Actions → Jenkins (Recommended)

This method uses GitHub Actions to trigger Jenkins, providing better control and monitoring.

### Setup Steps:

#### 1. Configure GitHub Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions** and add:

```
JENKINS_URL=https://your-jenkins-server.com
JENKINS_USER=your-jenkins-username
JENKINS_TOKEN=your-jenkins-api-token
```

#### 2. GitHub Actions Workflow

The workflow file `.github/workflows/trigger-jenkins.yml` is already created and will:
- Trigger on pushes to main, develop, and release branches
- Allow manual triggers with custom parameters
- Create deployment statuses in GitHub
- Comment on pull requests with deployment info

#### 3. Jenkins Job Configuration

Import the `jenkins-job-config.xml` file into Jenkins:

1. Go to Jenkins Dashboard
2. Click "New Item"
3. Enter job name: `CEA-Commerce-Deployment`
4. Select "Pipeline"
5. In job configuration, go to "Pipeline" section
6. Select "Pipeline script from SCM"
7. Choose "Git" as SCM
8. Enter your repository URL
9. Set credentials for GitHub access
10. Set branch to `*/main`
11. Set script path to `Jenkinsfile`

## Method 2: Direct GitHub Webhooks (Alternative)

### Setup Steps:

#### 1. Install Jenkins Plugins

Install these plugins in Jenkins:
- GitHub Plugin
- GitHub Branch Source Plugin
- Pipeline: GitHub Groovy Libraries
- Generic Webhook Trigger Plugin

#### 2. Configure Jenkins Job for Webhooks

1. In your Jenkins job configuration, go to "Build Triggers"
2. Check "GitHub hook trigger for GITScm polling"
3. Or use "Generic Webhook Trigger" for more control

#### 3. Set Up GitHub Webhook

1. Go to your GitHub repository
2. Navigate to **Settings > Webhooks**
3. Click "Add webhook"
4. Configure webhook:

```
Payload URL: https://your-jenkins-server.com/github-webhook/
Content type: application/json
Secret: (optional, for security)
Events: 
  - Push events
  - Pull request events
  - Release events
```

#### 4. Jenkins Webhook URL Formats

Different webhook URLs for different triggers:

```bash
# GitHub Plugin webhook
https://jenkins.example.com/github-webhook/

# Generic webhook with parameters
https://jenkins.example.com/generic-webhook-trigger/invoke?token=YOUR_TOKEN

# Parameterized webhook
https://jenkins.example.com/job/CEA-Commerce-Deployment/buildWithParameters?token=BUILD_TOKEN&ENVIRONMENT=dev
```

## 🔐 Security Configuration

### Jenkins Security

1. **API Token Generation:**
   ```
   Jenkins → User Menu → Configure → API Token → Add new Token
   ```

2. **Job-specific Build Token:**
   ```
   Job Configuration → Build Triggers → Trigger builds remotely → Authentication Token
   ```

3. **CSRF Protection:**
   ```
   Manage Jenkins → Configure Global Security → CSRF Protection
   ```

### GitHub Security

1. **Webhook Secret:**
   ```bash
   # Generate secure secret
   openssl rand -hex 20
   ```

2. **Repository Access:**
   - Use deploy keys for read-only access
   - Use GitHub Apps for better security
   - Limit webhook to specific events

## 📋 Webhook Payload Examples

### Push Event Payload
```json
{
  "ref": "refs/heads/main",
  "before": "abc123...",
  "after": "def456...",
  "repository": {
    "name": "cea-commerce-deployment",
    "full_name": "your-org/cea-commerce-deployment"
  },
  "pusher": {
    "name": "developer"
  },
  "commits": [...]
}
```

### Pull Request Event Payload
```json
{
  "action": "opened",
  "number": 123,
  "pull_request": {
    "head": {
      "ref": "feature-branch",
      "sha": "abc123..."
    },
    "base": {
      "ref": "main"
    }
  }
}
```

## 🎯 Trigger Logic Configuration

### Branch-based Deployment Logic

```groovy
// In Jenkinsfile - determine environment based on branch
def getEnvironment(branchName) {
    if (branchName == 'main' || branchName == 'master') {
        return 'prod'
    } else if (branchName == 'develop') {
        return 'dev'
    } else if (branchName.startsWith('release/')) {
        return 'staging'
    } else {
        return 'dev'  // default for feature branches
    }
}

pipeline {
    agent any
    
    environment {
        DEPLOYMENT_ENV = getEnvironment(env.BRANCH_NAME)
    }
    
    // ... rest of pipeline
}
```

### Custom Webhook Parameters

For Generic Webhook Trigger plugin:

```groovy
pipeline {
    agent any
    
    triggers {
        GenericTrigger(
            genericVariables: [
                [key: 'ref', value: '$.ref'],
                [key: 'repository', value: '$.repository.full_name'],
                [key: 'pusher', value: '$.pusher.name']
            ],
            causeString: 'Triggered by GitHub webhook',
            token: 'your-webhook-token',
            printContributedVariables: true,
            printPostContent: true
        )
    }
    
    stages {
        stage('Process Webhook') {
            steps {
                script {
                    echo "Branch: ${ref}"
                    echo "Repository: ${repository}"
                    echo "Pusher: ${pusher}"
                }
            }
        }
    }
}
```

## 🔍 Testing Webhook Integration

### 1. Test GitHub Actions Trigger

```bash
# Push to trigger deployment
git add .
git commit -m "Test deployment trigger"
git push origin main

# Check GitHub Actions tab for workflow execution
# Check Jenkins for triggered build
```

### 2. Test Manual GitHub Actions Trigger

1. Go to GitHub repository
2. Click "Actions" tab
3. Select "Trigger Jenkins Deployment"
4. Click "Run workflow"
5. Select parameters and run

### 3. Test Direct Webhook

```bash
# Test webhook with curl
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d @test-payload.json \
  https://your-jenkins-server.com/github-webhook/
```

### 4. Webhook Testing Tools

- **ngrok**: For local Jenkins testing
- **webhook.site**: For webhook payload inspection
- **GitHub webhook deliveries**: Check recent deliveries in repo settings

## 🐛 Troubleshooting

### Common Issues

#### 1. Webhook Not Triggering Jenkins

**Check:**
- Jenkins URL is accessible from GitHub
- Webhook URL is correct
- Jenkins job is configured for webhook triggers
- GitHub webhook shows successful deliveries

**Solutions:**
```bash
# Test Jenkins accessibility
curl -I https://your-jenkins-server.com/github-webhook/

# Check Jenkins logs
tail -f /var/log/jenkins/jenkins.log

# Verify webhook configuration
# GitHub: Settings > Webhooks > Recent Deliveries
```

#### 2. Authentication Issues

**Check:**
- Jenkins API token is valid
- GitHub credentials are correct
- CSRF protection settings

**Solutions:**
```bash
# Test Jenkins API
curl -u username:token https://jenkins.example.com/api/json

# Regenerate API token if needed
```

#### 3. GitHub Actions Not Triggering

**Check:**
- Workflow file syntax
- GitHub secrets are set
- Branch protection rules
- Action permissions

**Debug:**
```yaml
# Add debug step to workflow
- name: Debug
  run: |
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "SHA: ${{ github.sha }}"
```

### Monitoring and Logs

#### Jenkins Logs
```bash
# Main Jenkins log
tail -f /var/log/jenkins/jenkins.log

# Job-specific logs
# Available in Jenkins UI: Job > Build History > Console Output
```

#### GitHub Webhook Logs
```
Repository Settings > Webhooks > Recent Deliveries
- Check response codes
- View request/response payloads
- Redeliver failed webhooks
```

#### GitHub Actions Logs
```
Repository > Actions > Workflow Run > Job Details
- View step-by-step execution
- Check environment variables
- Debug failed steps
```

## 📈 Advanced Configuration

### Multi-Environment Webhooks

```groovy
// Different webhook tokens for different environments
pipeline {
    agent any
    
    triggers {
        GenericTrigger(
            genericVariables: [
                [key: 'branch', value: '$.ref', regexpFilter: 'refs/heads/(.*)']
            ],
            causeString: 'Triggered by $branch',
            token: env.BRANCH_NAME == 'main' ? 'prod-token' : 'dev-token'
        )
    }
}
```

### Conditional Deployments

```groovy
stage('Deploy') {
    when {
        anyOf {
            branch 'main'
            branch 'develop'
            branch 'release/*'
        }
    }
    steps {
        // Deployment steps
    }
}
```

### Webhook Security Headers

```groovy
// Verify GitHub webhook signature
pipeline {
    agent any
    
    stages {
        stage('Verify Webhook') {
            steps {
                script {
                    def signature = env.HTTP_X_HUB_SIGNATURE_256
                    def payload = env.WEBHOOK_PAYLOAD
                    
                    // Verify signature logic here
                    if (!verifySignature(signature, payload)) {
                        error("Invalid webhook signature")
                    }
                }
            }
        }
    }
}
```

This configuration provides a robust integration between GitHub and Jenkins for automated CEA Commerce deployments.