#!/bin/bash

# Conxian CI/CD Setup Script
# This script automates the setup of the CI/CD pipeline and monitoring

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Conxian CI/CD Setup...${NC}"

# Check for required tools
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${YELLOW}Error: $1 is not installed.${NC}"
        exit 1
    fi
}

# Verify required tools are installed
echo -e "${GREEN}Checking for required tools...${NC}"
for cmd in git docker docker-compose node npm jq; do
    check_command $cmd
done

# Clone repository if not already in one
echo -e "${GREEN}Setting up repository...${NC}"
if [ ! -d .git ]; then
    read -p "Enter repository URL: " repo_url
    if [ -n "$repo_url" ]; then
        git clone $repo_url .
        cd $(basename $repo_url .git)
    else
        git init
    fi
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${GREEN}Creating .env file...${NC}"
    cat > .env << 'EOL'
# Conxian CI/CD Configuration
NODE_ENV=development

# Docker
DOCKERHUB_USERNAME=your_dockerhub_username
DOCKER_IMAGE=conxian-protocol

# Monitoring
GRAFANA_ADMIN_PASSWORD=admin123
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
ALERTMANAGER_PORT=9093
NODE_EXPORTER_PORT=9100

# GitHub
GITHUB_TOKEN=your_github_token
GITHUB_OWNER=your_github_org
GITHUB_REPO=conxian-protocol

# Slack
SLACK_WEBHOOK_URL=your_slack_webhook_url
SLACK_CHANNEL=#alerts

# AWS (for deployments)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1

# Code Quality
SONAR_TOKEN=your_sonarqube_token
CODECOV_TOKEN=your_codecov_token
EOL
    
    echo -e "${YELLOW}Please update the .env file with your configuration.${NC}"
    exit 1
fi

# Install Node.js dependencies
echo -e "${GREEN}Installing Node.js dependencies...${NC}"
npm install

# Install Clarinet
echo -e "${GREEN}Installing Clarinet...${NC}"
CLARINET_VERSION="3.5.0"
if ! command -v clarinet &> /dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install clarinet
    else
        # Linux
        curl -L https://github.com/hirosystems/clarinet/releases/download/v${CLARINET_VERSION}/clarinet-linux-x64-glibc.tar.gz | tar xz
        chmod +x clarinet
        sudo mv clarinet /usr/local/bin/
    fi
fi

# Verify Clarinet installation
clarinet --version

# Set up Git hooks
echo -e "${GREEN}Setting up Git hooks...${NC}"
npx husky install

# Create pre-commit hook
cat > .husky/pre-commit << 'EOL'
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

# Run linter
echo "Running linter..."
npm run lint

# Run tests
echo "Running tests..."
npm test
EOL

chmod +x .husky/pre-commit

# Create commit-msg hook
cat > .husky/commit-msg << 'EOL'
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

# Validate commit message format
npx commitlint --edit $1
EOL

chmod +x .husky/commit-msg

# Set up monitoring
echo -e "${GREEN}Setting up monitoring...${NC}"
if [ ! -d monitoring ]; then
    mkdir -p monitoring/{prometheus,grafana,alertmanager}
    
    # Create Prometheus config
    cat > monitoring/prometheus/prometheus.yml << 'EOL'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - 'alert.rules.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOL

    # Create alert rules
    cat > monitoring/prometheus/alert.rules.yml << 'EOL'
groups:
- name: ci-cd-alerts
  rules:
  - alert: CICDPipelineFailed
    expr: github_actions_workflow_run_conclusion{conclusion="failure"} == 1
    for: 5m
    labels:
      severity: 'critical'
    annotations:
      summary: 'CI/CD Pipeline Failed'
      description: 'The CI/CD pipeline has failed.'
EOL

    # Create docker-compose file for monitoring
    cat > docker-compose.monitoring.yml << 'EOL'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    ports:
      - "${PROMETHEUS_PORT:-9090}:9090"
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ./monitoring/alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/config.yml'
    ports:
      - "${ALERTMANAGER_PORT:-9093}:9093"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - ./monitoring/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
    ports:
      - "${GRAFANA_PORT:-3000}:3000"
    depends_on:
      - prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
    ports:
      - "${NODE_EXPORTER_PORT:-9100}:9100"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
EOL

    echo -e "${GREEN}Monitoring setup complete. Run 'docker-compose -f docker-compose.monitoring.yml up -d' to start.${NC}"
fi

# Create GitHub Actions workflow directory
mkdir -p .github/workflows

# Create README for CI/CD setup
cat > CI_CD_SETUP.md << 'EOL'
# Conxian CI/CD Setup

## Prerequisites

- Docker and Docker Compose
- Node.js 18+
- npm 8+
- Git

## Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd conxian-protocol
   ```

2. Run the setup script:
   ```bash
   chmod +x scripts/setup-ci-cd.sh
   ./scripts/setup-ci-cd.sh
   ```

3. Update the `.env` file with your configuration.

4. Start the monitoring stack:
   ```bash
   docker-compose -f docker-compose.monitoring.yml up -d
   ```

## Access

- **Grafana**: http://localhost:3000
  - Username: admin
  - Password: (set in .env)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

## Development Workflow

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature
   ```

2. Make your changes and commit:
   ```bash
   git add .
   git commit -m "feat: add your feature"
   ```

3. Push your changes and create a pull request.

## Monitoring

The monitoring stack includes:
- Prometheus for metrics collection
- Grafana for visualization
- Alertmanager for alerts
- Node Exporter for system metrics

## Troubleshooting

- View logs: `docker-compose -f docker-compose.monitoring.yml logs -f`
- Check Prometheus targets: http://localhost:9090/targets
- View alerts: http://localhost:9093

## License

[Your License Here]
EOL

echo -e "${GREEN}CI/CD setup complete!${NC}"
echo -e "${YELLOW}Please review and update the .env file with your configuration.${NC}"
echo -e "${GREEN}Documentation has been generated in CI_CD_SETUP.md${NC}"
