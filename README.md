# CEA Commerce Jenkins Pipeline for AWS EC2 Deployment

This Jenkins pipeline automates the deployment of CEA Commerce cloud setup on AWS EC2 instances, converting the Windows-based process to a Linux environment.

## 🏗️ Architecture Overview

The pipeline deploys CEA Commerce (SAP Hybris) to EC2 instances with the following structure:
- **Base Directory**: `/opt/CEASAP/`
- **Commerce Suite**: `/opt/CEASAP/cx/`
- **Custom Extensions**: `/opt/CEASAP/repo/`
- **Symbolic Links**: `/opt/CEASAP/cx/hybris/bin/custom/`

## 📋 Prerequisites

### AWS Resources
1. **EC2 Instances**: Running Amazon Linux 2 or Ubuntu
2. **Security Groups**: Allow SSH (22), HTTP (80), HTTPS (443), and Hybris (9001, 9002)
3. **IAM Role**: EC2 instances with necessary permissions
4. **Load Balancer**: Application Load Balancer (optional)
5. **S3 Bucket**: For storing Commerce Suite artifacts (optional)

### Jenkins Setup
1. **Plugins Required**:
   - AWS Pipeline Plugin
   - SSH Agent Plugin
   - Email Extension Plugin
   - Pipeline Stage View Plugin

2. **Credentials Configuration**:
   ```
   - AWS Credentials (ID: 'aws-credentials')
   - SSH Private Key for EC2 (ID: 'ec2-keypair')
   - Git Repository Access (if private)
   ```

### EC2 Instance Requirements
```bash
# Install required packages on EC2 instances
sudo yum update -y
sudo yum install -y java-11-openjdk-devel wget unzip git curl

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' >> ~/.bashrc
source ~/.bashrc
```

## ⚙️ Configuration

### 1. Update Environment Variables

Edit the `environment` section in the Jenkinsfile:

```groovy
environment {
    AWS_DEFAULT_REGION = 'us-east-1'                    // Your AWS region
    AWS_CREDENTIALS_ID = 'aws-credentials'              // Jenkins credential ID
    EC2_KEY_PAIR = 'ec2-keypair'                       // SSH key credential ID
    COMMERCE_SUITE_URL = 'https://your-repo/Commerce-suite-2211.FP6.240510019.zip'
    GIT_REPO_URL = 'https://github.com/your-org/your-commerce-repo.git'
    EC2_INSTANCE_IDS = 'i-1234567890abcdef0,i-0987654321fedcba0'  // Comma-separated
    CEASAP_HOME = '/opt/CEASAP'
    HYBRIS_HOME = '/opt/CEASAP/cx'
}
```

### 2. Configure Load Balancer (Optional)

Update the target group ARN in the `Configure Load Balancer` stage:

```groovy
aws elbv2 register-targets \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/name/id \
    --targets Id=${EC2_INSTANCE_IDS//,/ Id=}
```

### 3. Jenkins Credentials Setup

#### AWS Credentials
1. Go to Jenkins → Manage Jenkins → Manage Credentials
2. Add AWS credentials with ID: `aws-credentials`
3. Use IAM Access Key/Secret Key or IAM Role

#### SSH Key for EC2
1. Add SSH Private Key with ID: `ec2-keypair`
2. Use the private key corresponding to your EC2 key pair

## 🚀 Pipeline Stages

### Stage Breakdown

1. **Preparation**: Initialize deployment parameters
2. **Setup Directory Structure**: Create `/opt/CEASAP/cx` and `/opt/CEASAP/repo`
3. **Download Commerce Suite**: Download and extract Commerce-suite-2211.FP6.240510019.zip
4. **Create Custom Directory**: Set up `/opt/CEASAP/cx/hybris/bin/custom`
5. **Clone Repository**: Pull custom extensions from Git
6. **Create Symbolic Links**: Link custom extensions to Hybris
7. **Install Commerce Suite**: Run the installer
8. **Build Platform**: Execute `ant clean all`
9. **Initialize System**: Run `ant initialize`
10. **Run Tests**: Execute unit and integration tests (optional)
11. **Start Hybris Server**: Launch server in debug mode
12. **Health Check**: Verify application is running
13. **Configure Load Balancer**: Register instances with ALB

## 🎛️ Pipeline Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DEPLOYMENT_ENVIRONMENT` | Choice | - | Target environment (dev/staging/prod) |
| `SKIP_TESTS` | Boolean | false | Skip running tests |
| `GIT_BRANCH` | String | main | Git branch to deploy |

## 📊 Usage

### Running the Pipeline

1. **Navigate to Jenkins Job**
2. **Click "Build with Parameters"**
3. **Select Parameters**:
   - Environment: `dev`, `staging`, or `prod`
   - Skip Tests: Check if you want to skip tests
   - Git Branch: Specify the branch to deploy
4. **Click "Build"**

### Monitoring

- **Build Console**: View real-time logs
- **Stage View**: Monitor pipeline progress
- **Blue Ocean**: Enhanced visualization (if installed)

## 🔧 Troubleshooting

### Common Issues

#### 1. SSH Connection Failed
```bash
# Check security groups allow SSH from Jenkins
# Verify SSH key is correct
# Test manual SSH connection
ssh -i your-key.pem ec2-user@instance-ip
```

#### 2. Java/Ant Issues
```bash
# Ensure Java 11 is installed
java -version

# Check JAVA_HOME
echo $JAVA_HOME

# Verify Ant is available
which ant
```

#### 3. Permission Issues
```bash
# Fix ownership of CEASAP directory
sudo chown -R ec2-user:ec2-user /opt/CEASAP

# Check directory permissions
ls -la /opt/CEASAP
```

#### 4. Hybris Server Won't Start
```bash
# Check logs
tail -f /opt/CEASAP/cx/hybris/bin/platform/hybris.log

# Verify ports are available
netstat -tulpn | grep 9001

# Check memory and disk space
free -h
df -h
```

### Log Locations

- **Jenkins Build Logs**: Jenkins UI → Build → Console Output
- **Hybris Logs**: `/opt/CEASAP/cx/hybris/bin/platform/hybris.log`
- **System Logs**: `/var/log/messages` or `/var/log/syslog`

## 🛡️ Security Considerations

1. **IAM Roles**: Use least privilege principle
2. **Security Groups**: Restrict access to necessary ports
3. **SSH Keys**: Rotate keys regularly
4. **Secrets**: Store sensitive data in Jenkins credentials
5. **Network**: Use private subnets where possible

## 📈 Monitoring and Alerts

### Health Checks
- Application responds on port 9001
- HAC (Hybris Administration Console) accessible
- Database connectivity verified

### Notifications
- Email notifications on success/failure
- Slack integration (add webhook URL)
- AWS SNS for critical alerts

## 🔄 Rollback Strategy

In case of deployment failure:

1. **Stop Current Deployment**
2. **Revert to Previous Version**:
   ```bash
   # SSH to instances
   cd /opt/CEASAP/cx/hybris/bin/platform
   ./hybrisserver.sh stop
   
   # Restore from backup or redeploy previous version
   # Restart server
   ./hybrisserver.sh start
   ```

## 📝 Customization

### Adding Custom Stages

```groovy
stage('Custom Pre-Deploy') {
    steps {
        script {
            def customCommands = """
                # Your custom commands here
                echo "Running custom pre-deployment tasks"
            """
            executeOnEC2Instances(customCommands)
        }
    }
}
```

### Environment-Specific Configuration

```groovy
script {
    def configFile = params.DEPLOYMENT_ENVIRONMENT == 'prod' ? 'prod.properties' : 'dev.properties'
    // Use different configurations per environment
}
```

## 📞 Support

For issues and questions:
- Check Jenkins build logs
- Review EC2 instance logs
- Verify AWS resource configurations
- Test connectivity manually

## 🏷️ Version History

- **v1.0**: Initial Linux conversion from Windows setup
- **v1.1**: Added AWS integration and EC2 deployment
- **v1.2**: Enhanced error handling and notifications