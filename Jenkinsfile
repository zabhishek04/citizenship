pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1' // Change as needed
        AWS_CREDENTIALS_ID = 'aws-credentials' // Configure in Jenkins credentials
        EC2_KEY_PAIR = 'ec2-keypair' // Configure in Jenkins credentials
        COMMERCE_SUITE_URL = 'https://your-artifact-repo/Commerce-suite-2211.FP6.240510019.zip'
        GIT_REPO_URL = 'https://github.com/your-org/your-commerce-repo.git' // Replace with actual repo
        EC2_INSTANCE_IDS = 'i-1234567890abcdef0,i-0987654321fedcba0' // Replace with actual instance IDs
        CEASAP_HOME = '/opt/CEASAP'
        HYBRIS_HOME = '/opt/CEASAP/cx'
    }
    
    parameters {
        choice(
            name: 'DEPLOYMENT_ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Select deployment environment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'main',
            description: 'Git branch to deploy'
        )
    }
    
    stages {
        stage('Preparation') {
            steps {
                script {
                    echo "Starting CEA Commerce deployment for ${params.DEPLOYMENT_ENVIRONMENT} environment"
                    echo "Git branch: ${params.GIT_BRANCH}"
                }
            }
        }
        
        stage('Setup Directory Structure') {
            steps {
                script {
                    echo "Creating CEASAP directory structure on EC2 instances"
                    
                    def setupCommands = """
                        sudo mkdir -p ${CEASAP_HOME}/cx
                        sudo mkdir -p ${CEASAP_HOME}/repo
                        sudo chown -R \$(whoami):\$(whoami) ${CEASAP_HOME}
                        ls -la ${CEASAP_HOME}
                    """
                    
                    executeOnEC2Instances(setupCommands)
                }
            }
        }
        
        stage('Download and Extract Commerce Suite') {
            steps {
                script {
                    echo "Downloading and extracting Commerce Suite on EC2 instances"
                    
                    def downloadCommands = """
                        cd ${CEASAP_HOME}/cx
                        wget -O Commerce-suite-2211.FP6.240510019.zip "${COMMERCE_SUITE_URL}"
                        unzip -q Commerce-suite-2211.FP6.240510019.zip
                        rm -f Commerce-suite-2211.FP6.240510019.zip
                        ls -la ${CEASAP_HOME}/cx
                    """
                    
                    executeOnEC2Instances(downloadCommands)
                }
            }
        }
        
        stage('Create Custom Directory') {
            steps {
                script {
                    echo "Creating custom directory in hybris/bin"
                    
                    def customDirCommands = """
                        mkdir -p ${CEASAP_HOME}/cx/hybris/bin/custom
                        ls -la ${CEASAP_HOME}/cx/hybris/bin/
                    """
                    
                    executeOnEC2Instances(customDirCommands)
                }
            }
        }
        
        stage('Clone Repository') {
            steps {
                script {
                    echo "Cloning Git repository into repo folder"
                    
                    def gitCommands = """
                        cd ${CEASAP_HOME}/repo
                        if [ -d .git ]; then
                            git fetch origin
                            git checkout ${params.GIT_BRANCH}
                            git pull origin ${params.GIT_BRANCH}
                        else
                            git clone -b ${params.GIT_BRANCH} ${GIT_REPO_URL} .
                        fi
                        ls -la ${CEASAP_HOME}/repo
                    """
                    
                    executeOnEC2Instances(gitCommands)
                }
            }
        }
        
        stage('Create Symbolic Links') {
            steps {
                script {
                    echo "Creating symbolic links for custom extensions"
                    
                    def symlinkCommands = """
                        cd ${CEASAP_HOME}/cx/hybris/bin/custom
                        
                        # Remove existing symbolic links if they exist
                        find . -type l -delete
                        
                        # Create symbolic links for all extensions in repo
                        for ext_dir in ${CEASAP_HOME}/repo/*/; do
                            if [ -d "\$ext_dir" ]; then
                                ext_name=\$(basename "\$ext_dir")
                                ln -sf "\$ext_dir" "\$ext_name"
                                echo "Created symlink for \$ext_name"
                            fi
                        done
                        
                        ls -la ${CEASAP_HOME}/cx/hybris/bin/custom/
                    """
                    
                    executeOnEC2Instances(symlinkCommands)
                }
            }
        }
        
        stage('Install Commerce Suite') {
            steps {
                script {
                    echo "Running Commerce Suite installer"
                    
                    def installerCommands = """
                        cd ${CEASAP_HOME}/cx/installer
                        chmod +x install.sh
                        ./install.sh -r ${params.DEPLOYMENT_ENVIRONMENT}
                    """
                    
                    executeOnEC2Instances(installerCommands)
                }
            }
        }
        
        stage('Build Platform') {
            steps {
                script {
                    echo "Building Hybris platform"
                    
                    def buildCommands = """
                        cd ${CEASAP_HOME}/cx/hybris/bin/platform
                        
                        # Set environment variables (Linux equivalent of setantenv.bat)
                        export PLATFORM_HOME=${CEASAP_HOME}/cx/hybris/bin/platform
                        export HYBRIS_HOME=${CEASAP_HOME}/cx
                        export PATH=\$PLATFORM_HOME/apache-ant/bin:\$PATH
                        
                        # Clean and build all
                        ./setantenv.sh
                        ant clean all
                        
                        echo "Build completed successfully"
                    """
                    
                    executeOnEC2Instances(buildCommands)
                }
            }
        }
        
        stage('Initialize System') {
            steps {
                script {
                    echo "Initializing Hybris system"
                    
                    def initCommands = """
                        cd ${CEASAP_HOME}/cx/hybris/bin/platform
                        
                        export PLATFORM_HOME=${CEASAP_HOME}/cx/hybris/bin/platform
                        export HYBRIS_HOME=${CEASAP_HOME}/cx
                        
                        ant initialize
                        
                        echo "System initialization completed"
                    """
                    
                    executeOnEC2Instances(initCommands)
                }
            }
        }
        
        stage('Run Tests') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                script {
                    echo "Running tests"
                    
                    def testCommands = """
                        cd ${CEASAP_HOME}/cx/hybris/bin/platform
                        
                        export PLATFORM_HOME=${CEASAP_HOME}/cx/hybris/bin/platform
                        export HYBRIS_HOME=${CEASAP_HOME}/cx
                        
                        ant unittests
                        ant integrationtests
                    """
                    
                    executeOnEC2Instances(testCommands)
                }
            }
        }
        
        stage('Start Hybris Server') {
            steps {
                script {
                    echo "Starting Hybris server in debug mode"
                    
                    def serverCommands = """
                        cd ${CEASAP_HOME}/cx/hybris/bin/platform
                        
                        export PLATFORM_HOME=${CEASAP_HOME}/cx/hybris/bin/platform
                        export HYBRIS_HOME=${CEASAP_HOME}/cx
                        
                        # Stop any existing server
                        ./hybrisserver.sh stop || true
                        
                        # Start server in debug mode
                        nohup ./hybrisserver.sh debug > hybris.log 2>&1 &
                        
                        # Wait for server to start
                        sleep 30
                        
                        # Check if server is running
                        if pgrep -f "hybris" > /dev/null; then
                            echo "Hybris server started successfully"
                        else
                            echo "Failed to start Hybris server"
                            exit 1
                        fi
                    """
                    
                    executeOnEC2Instances(serverCommands)
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo "Performing health check"
                    
                    def healthCheckCommands = """
                        # Wait for application to be ready
                        sleep 60
                        
                        # Check if Hybris is responding
                        curl -f http://localhost:9001/hac || exit 1
                        
                        echo "Health check passed"
                    """
                    
                    executeOnEC2Instances(healthCheckCommands)
                }
            }
        }
        
        stage('Configure Load Balancer') {
            steps {
                script {
                    echo "Updating load balancer configuration"
                    
                    withCredentials([aws(credentialsId: "${AWS_CREDENTIALS_ID}")]) {
                        sh """
                            # Register instances with load balancer
                            aws elbv2 register-targets \\
                                --target-group-arn arn:aws:elasticloadbalancing:${AWS_DEFAULT_REGION}:123456789012:targetgroup/my-targets/1234567890123456 \\
                                --targets Id=\${EC2_INSTANCE_IDS//,/ Id=}
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Deployment completed for environment: ${params.DEPLOYMENT_ENVIRONMENT}"
                
                // Collect logs from EC2 instances
                def logCommands = """
                    cd ${CEASAP_HOME}/cx/hybris/bin/platform
                    tail -n 100 hybris.log || echo "No hybris.log found"
                """
                
                executeOnEC2Instances(logCommands)
            }
        }
        
        success {
            script {
                echo "✅ CEA Commerce deployment successful!"
                
                // Send success notification
                emailext (
                    subject: "✅ CEA Commerce Deployment Successful - ${params.DEPLOYMENT_ENVIRONMENT}",
                    body: """
                        CEA Commerce has been successfully deployed to ${params.DEPLOYMENT_ENVIRONMENT} environment.
                        
                        Build Details:
                        - Job: ${env.JOB_NAME}
                        - Build: ${env.BUILD_NUMBER}
                        - Branch: ${params.GIT_BRANCH}
                        - Environment: ${params.DEPLOYMENT_ENVIRONMENT}
                        
                        Access the application at: http://your-load-balancer-url/hac
                    """,
                    to: "${env.CHANGE_AUTHOR_EMAIL}"
                )
            }
        }
        
        failure {
            script {
                echo "❌ CEA Commerce deployment failed!"
                
                // Send failure notification
                emailext (
                    subject: "❌ CEA Commerce Deployment Failed - ${params.DEPLOYMENT_ENVIRONMENT}",
                    body: """
                        CEA Commerce deployment to ${params.DEPLOYMENT_ENVIRONMENT} environment has failed.
                        
                        Build Details:
                        - Job: ${env.JOB_NAME}
                        - Build: ${env.BUILD_NUMBER}
                        - Branch: ${params.GIT_BRANCH}
                        - Environment: ${params.DEPLOYMENT_ENVIRONMENT}
                        
                        Please check the build logs for more details.
                    """,
                    to: "${env.CHANGE_AUTHOR_EMAIL}"
                )
            }
        }
    }
}

def executeOnEC2Instances(commands) {
    def instanceIds = EC2_INSTANCE_IDS.split(',')
    
    withCredentials([
        aws(credentialsId: "${AWS_CREDENTIALS_ID}"),
        sshUserPrivateKey(credentialsId: "${EC2_KEY_PAIR}", keyFileVariable: 'SSH_KEY')
    ]) {
        instanceIds.each { instanceId ->
            instanceId = instanceId.trim()
            
            // Get instance IP
            def instanceIp = sh(
                script: "aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text",
                returnStdout: true
            ).trim()
            
            echo "Executing commands on instance ${instanceId} (${instanceIp})"
            
            // Execute commands via SSH
            sh """
                ssh -i \$SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@${instanceIp} '
                    set -e
                    ${commands}
                '
            """
        }
    }
}