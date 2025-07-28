#!/bin/bash

# CEA Commerce EC2 Instance Setup Script
# This script prepares an EC2 instance for CEA Commerce deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as ec2-user or ubuntu."
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    error "Cannot detect OS version"
fi

log "Detected OS: $OS $VER"

# Update system packages
log "Updating system packages..."
if [[ "$OS" == *"Amazon Linux"* ]]; then
    sudo yum update -y
    PACKAGE_MANAGER="yum"
elif [[ "$OS" == *"Ubuntu"* ]]; then
    sudo apt-get update -y
    sudo apt-get upgrade -y
    PACKAGE_MANAGER="apt-get"
else
    error "Unsupported OS: $OS"
fi

# Install required packages
log "Installing required packages..."
if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
    sudo yum install -y \
        java-11-openjdk-devel \
        wget \
        unzip \
        git \
        curl \
        htop \
        tree \
        vim \
        net-tools \
        telnet \
        nc
elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
    sudo apt-get install -y \
        openjdk-11-jdk \
        wget \
        unzip \
        git \
        curl \
        htop \
        tree \
        vim \
        net-tools \
        telnet \
        netcat
fi

# Set JAVA_HOME
log "Setting up Java environment..."
if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
    JAVA_HOME_PATH="/usr/lib/jvm/java-11-openjdk"
elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
    JAVA_HOME_PATH="/usr/lib/jvm/java-11-openjdk-amd64"
fi

# Add JAVA_HOME to bashrc if not already present
if ! grep -q "JAVA_HOME" ~/.bashrc; then
    echo "export JAVA_HOME=$JAVA_HOME_PATH" >> ~/.bashrc
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc
    log "Added JAVA_HOME to ~/.bashrc"
fi

# Source bashrc
source ~/.bashrc

# Verify Java installation
log "Verifying Java installation..."
java -version
javac -version

# Create CEASAP directory structure
log "Creating CEASAP directory structure..."
sudo mkdir -p /opt/CEASAP/{cx,repo}
sudo chown -R $(whoami):$(whoami) /opt/CEASAP
log "Created /opt/CEASAP directory with proper permissions"

# Create hybris user (optional, for better security)
log "Creating hybris system user..."
if ! id "hybris" &>/dev/null; then
    sudo useradd -r -s /bin/bash -d /opt/CEASAP -m hybris
    sudo usermod -a -G $(whoami) hybris
    log "Created hybris user"
else
    log "hybris user already exists"
fi

# Set up log rotation for hybris logs
log "Setting up log rotation..."
sudo tee /etc/logrotate.d/hybris > /dev/null <<EOF
/opt/CEASAP/cx/hybris/bin/platform/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $(whoami) $(whoami)
    postrotate
        # Restart hybris if running
        if pgrep -f "hybris" > /dev/null; then
            /opt/CEASAP/cx/hybris/bin/platform/hybrisserver.sh restart
        fi
    endscript
}
EOF

# Configure firewall (if firewalld is available)
if command -v firewall-cmd &> /dev/null; then
    log "Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=9001/tcp  # Hybris HTTP
    sudo firewall-cmd --permanent --add-port=9002/tcp  # Hybris HTTPS
    sudo firewall-cmd --permanent --add-port=8000/tcp  # Debug port
    sudo firewall-cmd --reload
    log "Firewall configured for Hybris ports"
fi

# Configure system limits
log "Configuring system limits..."
sudo tee -a /etc/security/limits.conf > /dev/null <<EOF
# Hybris limits
$(whoami) soft nofile 65536
$(whoami) hard nofile 65536
$(whoami) soft nproc 32768
$(whoami) hard nproc 32768
hybris soft nofile 65536
hybris hard nofile 65536
hybris soft nproc 32768
hybris hard nproc 32768
EOF

# Configure sysctl for better performance
log "Configuring kernel parameters..."
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
# Hybris performance tuning
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF

sudo sysctl -p

# Install monitoring tools
log "Installing monitoring tools..."
if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
    # Install CloudWatch agent (optional)
    if ! command -v amazon-cloudwatch-agent-ctl &> /dev/null; then
        wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
        sudo rpm -U ./amazon-cloudwatch-agent.rpm
        rm -f amazon-cloudwatch-agent.rpm
        log "Installed CloudWatch agent"
    fi
fi

# Create systemd service for Hybris (optional)
log "Creating systemd service for Hybris..."
sudo tee /etc/systemd/system/hybris.service > /dev/null <<EOF
[Unit]
Description=SAP Hybris Commerce Server
After=network.target

[Service]
Type=forking
User=$(whoami)
Group=$(whoami)
Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=HYBRIS_HOME=/opt/CEASAP/cx
Environment=PLATFORM_HOME=/opt/CEASAP/cx/hybris/bin/platform
WorkingDirectory=/opt/CEASAP/cx/hybris/bin/platform
ExecStart=/opt/CEASAP/cx/hybris/bin/platform/hybrisserver.sh start
ExecStop=/opt/CEASAP/cx/hybris/bin/platform/hybrisserver.sh stop
ExecReload=/opt/CEASAP/cx/hybris/bin/platform/hybrisserver.sh restart
Restart=on-failure
RestartSec=30
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
log "Created hybris systemd service"

# Create health check script
log "Creating health check script..."
tee /opt/CEASAP/health-check.sh > /dev/null <<'EOF'
#!/bin/bash

# Hybris Health Check Script
HYBRIS_URL="http://localhost:9001/hac"
MAX_ATTEMPTS=10
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Health check attempt $ATTEMPT/$MAX_ATTEMPTS"
    
    # Check if Hybris process is running
    if ! pgrep -f "hybris" > /dev/null; then
        echo "❌ Hybris process not running"
        exit 1
    fi
    
    # Check if port 9001 is listening
    if ! netstat -tulpn | grep -q ":9001 "; then
        echo "❌ Port 9001 not listening"
        exit 1
    fi
    
    # Check HTTP response
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HYBRIS_URL || echo "000")
    
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
        echo "✅ Hybris is healthy (HTTP $HTTP_STATUS)"
        exit 0
    else
        echo "⚠️  HTTP status: $HTTP_STATUS (attempt $ATTEMPT/$MAX_ATTEMPTS)"
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

echo "❌ Health check failed after $MAX_ATTEMPTS attempts"
exit 1
EOF

chmod +x /opt/CEASAP/health-check.sh
log "Created health check script at /opt/CEASAP/health-check.sh"

# Create backup script
log "Creating backup script..."
tee /opt/CEASAP/backup.sh > /dev/null <<'EOF'
#!/bin/bash

# Hybris Backup Script
BACKUP_DIR="/opt/CEASAP/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="hybris_backup_$DATE"

mkdir -p $BACKUP_DIR

echo "Starting backup: $BACKUP_NAME"

# Stop Hybris if running
if pgrep -f "hybris" > /dev/null; then
    echo "Stopping Hybris..."
    /opt/CEASAP/cx/hybris/bin/platform/hybrisserver.sh stop
    RESTART_HYBRIS=true
fi

# Create backup
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --exclude='/opt/CEASAP/cx/hybris/log/*' \
    --exclude='/opt/CEASAP/cx/hybris/temp/*' \
    --exclude='/opt/CEASAP/cx/hybris/data/media/*' \
    /opt/CEASAP/cx/hybris/config \
    /opt/CEASAP/cx/hybris/bin/custom

echo "Backup created: $BACKUP_DIR/$BACKUP_NAME.tar.gz"

# Restart Hybris if it was running
if [ "$RESTART_HYBRIS" = true ]; then
    echo "Restarting Hybris..."
    /opt/CEASAP/cx/hybris/bin/platform/hybrisserver.sh start
fi

# Clean old backups (keep last 7 days)
find $BACKUP_DIR -name "hybris_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed successfully"
EOF

chmod +x /opt/CEASAP/backup.sh
log "Created backup script at /opt/CEASAP/backup.sh"

# Set up cron job for daily backups
log "Setting up daily backup cron job..."
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/CEASAP/backup.sh >> /var/log/hybris-backup.log 2>&1") | crontab -

# Display system information
log "System setup completed! Here's the summary:"
echo "=================================================="
echo "OS: $OS $VER"
echo "Java Version: $(java -version 2>&1 | head -n1)"
echo "JAVA_HOME: $JAVA_HOME_PATH"
echo "CEASAP Directory: /opt/CEASAP"
echo "Available Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Available Disk: $(df -h / | tail -1 | awk '{print $4}')"
echo "=================================================="

log "✅ EC2 instance setup completed successfully!"
log "You can now run the Jenkins pipeline to deploy CEA Commerce."

# Final recommendations
echo ""
log "📝 Next Steps:"
echo "1. Update the Jenkinsfile with your specific configuration"
echo "2. Configure Jenkins credentials for AWS and SSH"
echo "3. Run the Jenkins pipeline to deploy CEA Commerce"
echo "4. Monitor logs at /opt/CEASAP/cx/hybris/bin/platform/hybris.log"
echo "5. Use health check: /opt/CEASAP/health-check.sh"
echo "6. Use backup script: /opt/CEASAP/backup.sh"

log "🔧 Useful commands:"
echo "- Check Hybris status: sudo systemctl status hybris"
echo "- Start Hybris: sudo systemctl start hybris"
echo "- Stop Hybris: sudo systemctl stop hybris"
echo "- View logs: tail -f /opt/CEASAP/cx/hybris/bin/platform/hybris.log"
echo "- Health check: /opt/CEASAP/health-check.sh"