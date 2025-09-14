#!/bin/bash

# Conxian CI/CD Monitoring Setup Script
# This script sets up monitoring and alerting for the CI/CD pipeline

set -e

# Configuration
GRAFANA_VERSION="9.5.2"
PROMETHEUS_VERSION="2.45.0"
ALERTMANAGER_VERSION="0.26.0"
NODE_EXPORTER_VERSION="1.6.1"

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Create necessary directories
echo -e "${GREEN}Creating directories...${NC}"
mkdir -p monitoring/{prometheus,grafana,alertmanager}

# Create Docker Compose file
echo -e "${GREEN}Creating Docker Compose configuration...${NC}"
cat > docker-compose.monitoring.yml << 'EOL'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:${PROMETHEUS_VERSION}
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - "9090:9090"
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:${ALERTMANAGER_VERSION}
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ./monitoring/alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/config.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "9093:9093"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:${GRAFANA_VERSION}
    container_name: grafana
    restart: unless-stopped
    volumes:
      - ./monitoring/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:${NODE_EXPORTER_VERSION}
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points'
      - '^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
EOL

# Create Prometheus configuration
echo -e "${GREEN}Creating Prometheus configuration...${NC}"
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

  - job_name: 'github-actions'
    metrics_path: '/metrics'
    scheme: https
    static_configs:
      - targets: ['api.github.com']
    metrics_path: /repos/your-org/your-repo/actions/runs
    params:
      per_page: ['1']
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: api.github.com:443
EOL

# Create Alertmanager configuration
echo -e "${GREEN}Creating Alertmanager configuration...${NC}"
cat > monitoring/alertmanager/config.yml << 'EOL'
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 3h
  receiver: 'slack'

receivers:
- name: 'slack'
  slack_configs:
  - api_url: '${SLACK_WEBHOOK_URL}'
    channel: '#alerts'
    send_resolved: true
    title: '{{ .CommonAnnotations.summary }}'
    text: |
      *Alert:* {{ .CommonAnnotations.description }}
      *Severity:* {{ .CommonLabels.severity }}
      *Status:* {{ .Status | toUpper }}
      *Starts at:* {{ .StartsAt | time }}
      *Ends at:* {{ .EndsAt | time }}
      *Labels:*
      {{ range .Labels.SortedPairs }}• {{ .Name }}: `{{ .Value }}`
      {{ end }}

inhibit_rules:
- source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  equal: ['alertname', 'dev', 'instance']
EOL

# Create alert rules
echo -e "${GREEN}Creating alert rules...${NC}"
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
      description: 'The CI/CD pipeline for {{ $labels.repository }} has failed.'

  - alert: HighErrorRate
    expr: rate(github_actions_workflow_run_conclusion{conclusion="failure"}[5m]) > 0.1
    for: 10m
    labels:
      severity: 'warning'
    annotations:
      summary: 'High CI/CD Failure Rate'
      description: 'High failure rate ({{ $value }}) in CI/CD pipeline for {{ $labels.repository }}.'

  - alert: NodeExporterDown
    expr: up{job="node-exporter"} == 0
    for: 5m
    labels:
      severity: 'critical'
    annotations:
      summary: 'Node Exporter Down'
      description: 'Node Exporter on {{ $labels.instance }} is down.'
EOL

# Set permissions
echo -e "${GREEN}Setting up permissions...${NC}"
chmod -R 777 monitoring

# Start the monitoring stack
echo -e "${GREEN}Starting monitoring stack...${NC}"
docker-compose -f docker-compose.monitoring.yml up -d

echo -e "${GREEN}Monitoring stack has been deployed!${NC}"
echo "- Grafana: http://localhost:3000 (admin/admin)"
echo "- Prometheus: http://localhost:9090"
echo "- Alertmanager: http://localhost:9093"

# Create a README for the monitoring setup
cat > monitoring/README.md << 'EOL'
# Conxian CI/CD Monitoring

This directory contains the configuration for monitoring the Conxian CI/CD pipeline.

## Components

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification
- **Node Exporter**: System metrics collection

## Setup

1. Install Docker and Docker Compose
2. Set environment variables in `.env` file:
   ```
   GRAFANA_ADMIN_PASSWORD=your_secure_password
   SLACK_WEBHOOK_URL=your_slack_webhook_url
   ```
3. Run the setup script:
   ```bash
   chmod +x ../scripts/setup-monitoring.sh
   ../scripts/setup-monitoring.sh
   ```

## Access

- **Grafana**: http://localhost:3000
  - Username: admin
  - Password: (set in .env or default: admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

## Adding Dashboards

1. Log in to Grafana
2. Import the dashboard JSON from `monitoring/dashboards/`
3. Configure the Prometheus data source if needed

## Alerting

Alerts are configured in `monitoring/prometheus/alert.rules.yml` and managed by Alertmanager.

## Troubleshooting

- Check container logs: `docker-compose -f docker-compose.monitoring.yml logs -f`
- Verify Prometheus targets: http://localhost:9090/targets
- Check Alertmanager status: http://localhost:9093/#/status
EOL

echo -e "${GREEN}Monitoring setup complete!${NC}"
