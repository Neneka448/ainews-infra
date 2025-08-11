# AiNews Infrastructure Stack

A comprehensive microservices infrastructure stack built with Docker Compose, featuring service discovery, message queuing, logging, and monitoring capabilities.

## 🏗️ Architecture Overview

This infrastructure provides a production-ready foundation for microservices deployment with:

- **Service Discovery & Configuration**: Nacos with JWT authentication
- **Message Queue**: Kafka in KRaft mode (no ZooKeeper required)
- **Logging Stack**: Loki + Promtail + Grafana with dynamic configuration
- **Monitoring Stack**: Prometheus + Grafana + Kafka Exporter
- **Dynamic Configuration**: Promtail log collection rules managed via Nacos

## 📁 Directory Structure

```
ainews-infra/
├── docker-compose.yml              # Main orchestration file
├── README.md                       # This documentation
├── ARCHITECTURE.md                 # Detailed architecture documentation
│
├── grafana-provisioning/           # Grafana auto-configuration
│   └── datasources/
│       └── datasource.yml         # Auto-provision Loki & Prometheus datasources
│
├── scripts/                        # Automation scripts
│   └── sync-promtail-config.sh    # Nacos config sync script for Promtail
│
├── promtail-sd/                    # Promtail service discovery
│   └── selectors.yml              # Dynamic log collection targets
│
├── nacos-configs/                  # Nacos configuration examples
│   └── promtail-selectors-example.yml  # Example Promtail config for Nacos
│
├── loki-config.yml                # Loki storage configuration
├── promtail-config.yml            # Promtail main configuration
└── prometheus.yml                 # Prometheus scraping configuration
```

## 📋 File Descriptions

### Core Configuration Files

| File | Purpose | Description |
|------|---------|-------------|
| `docker-compose.yml` | Service Orchestration | Defines all services, networks, volumes, and dependencies |
| `loki-config.yml` | Log Storage | Loki configuration for log storage and retention |
| `promtail-config.yml` | Log Collection | Promtail configuration for Docker log collection |
| `prometheus.yml` | Metrics Collection | Prometheus scraping targets and rules |

### Dynamic Configuration

| File | Purpose | Description |
|------|---------|-------------|
| `scripts/sync-promtail-config.sh` | Config Sync | Syncs Promtail selectors from Nacos every 30 seconds |
| `promtail-sd/selectors.yml` | Service Discovery | Dynamic log collection targets (managed by Nacos) |
| `nacos-configs/promtail-selectors-example.yml` | Example Config | Sample Promtail configuration for Nacos |

### Grafana Auto-Provisioning

| File | Purpose | Description |
|------|---------|-------------|
| `grafana-provisioning/datasources/datasource.yml` | Data Sources | Auto-configures Loki and Prometheus datasources |

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 8GB+ RAM recommended
- Ports 3000, 3100, 8848, 9090, 9092, 9094, 9308 available

### 1. Start All Services

```bash
# Clone and enter the directory
git clone <repository-url>
cd ainews-infra

# Start all services
docker compose up -d

# Check service status
docker compose ps
```

### 2. Verify Services

```bash
# Check all services are running
docker compose ps

# Check service logs
docker compose logs -f nacos
docker compose logs -f kafka
docker compose logs -f loki
docker compose logs -f promtail
```

### 3. Access Web Interfaces

| Service | URL | Credentials |
|---------|-----|-------------|
| **Nacos Console** | http://localhost:8848/nacos | `nacos` / `nacos` |
| **Grafana Dashboard** | http://localhost:3000 | `admin` / `admin` |
| **Prometheus UI** | http://localhost:9090 | No authentication |
| **Loki API** | http://localhost:3100 | No authentication |

## 🔧 Service Management

### Health Checks

```bash
# Quick health check
curl -f http://localhost:8848/nacos/       # Nacos
curl -f http://localhost:3000/api/health   # Grafana
curl -f http://localhost:9090/-/healthy    # Prometheus
curl -f http://localhost:3100/ready        # Loki

# Kafka health check
docker compose exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list
```

### Service Operations

```bash
# Restart specific service
docker compose restart nacos
docker compose restart kafka
docker compose restart promtail

# View service logs
docker compose logs -f --tail 50 nacos
docker compose logs -f --tail 50 kafka

# Scale services (if needed)
docker compose up -d --scale promtail=1
```

### Volume Management

```bash
# List all volumes
docker volume ls | grep ainews-infra

# Inspect volume contents
docker volume inspect ainews-infra_nacos-data
docker volume inspect ainews-infra_app-logs

# Backup volumes (example)
docker run --rm -v ainews-infra_nacos-data:/data -v $(pwd):/backup alpine tar czf /backup/nacos-backup.tar.gz -C /data .
```

## 📊 Monitoring & Logging

### Access Grafana Dashboards

1. **Login to Grafana**: http://localhost:3000 (`admin`/`admin`)
2. **Data Sources**: Pre-configured Loki and Prometheus
3. **Create Dashboards**: Use Loki for logs, Prometheus for metrics

### Query Examples

**Loki Log Queries:**
```logql
# All container logs
{job="docker-containers"}

# Specific service logs
{job="infrastructure-nacos"}

# Application service logs
{job="application-services"}

# Error logs only
{job="docker-containers"} |= "ERROR"
```

**Prometheus Metric Queries:**
```promql
# Kafka JVM memory usage
kafka_server_kafka_server_brokertopicmetrics_bytestot_total

# Container resource usage
rate(container_cpu_usage_seconds_total[5m])
```

## ⚙️ Configuration Management

### Nacos Configuration

1. **Access Nacos Console**: http://localhost:8848/nacos
2. **Login**: `nacos` / `nacos`
3. **Navigate**: Configuration Management → Configuration List
4. **Create Config**:
   - **Data ID**: `promtail-selectors`
   - **Group**: `DEFAULT_GROUP`
   - **Format**: `YAML`

### Dynamic Promtail Configuration

The `promtail-config-sync` service automatically syncs log collection rules from Nacos:

```yaml
# Example Nacos configuration for business services
- targets:
    - localhost
  labels:
    job: application-services
    __path__: /app-logs/*.log
    service_type: application
    environment: development

# Example for infrastructure services
- targets:
    - localhost
  labels:
    job: infrastructure-services
    __path__: /var/lib/docker/containers/*/*-json.log
    service_type: infrastructure
    environment: development
```

## 🏢 Adding New Services

### Business Application Template

```yaml
# Add to docker-compose.yml
services:
  your-business-service:
    image: your-service:latest
    container_name: your-service
    volumes:
      - app-logs:/app/logs  # Unified log directory
    environment:
      - LOG_PATH=/app/logs/your-service.log
      - SERVICE_NAME=your-service
    labels:
      - "log.service=your-service"
      - "log.type=application"
    # Other configurations...
```

### No Manual Log Configuration Required

- Business service logs → Automatically collected from `/app-logs/*.log`
- Infrastructure service logs → Automatically collected from Docker containers
- Configuration changes → Managed via Nacos (no restart required)

## 🛠️ Troubleshooting

### Common Issues

```bash
# Service won't start
docker compose logs <service-name>

# Port conflicts
docker compose down
# Edit docker-compose.yml to change ports
docker compose up -d

# Volume permission issues
docker compose down -v  # Remove volumes
docker compose up -d    # Recreate

# Nacos authentication issues
docker compose logs nacos | grep -i "auth\|jwt\|token"
```

### Reset Everything

```bash
# Stop and remove everything
docker compose down -v --remove-orphans

# Remove all related images (optional)
docker images | grep -E "(nacos|kafka|loki|grafana|prometheus|promtail)" | awk '{print $3}' | xargs docker rmi

# Start fresh
docker compose up -d
```

## 📈 Performance Tuning

### Resource Allocation

```yaml
# Example resource limits in docker-compose.yml
services:
  nacos:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
```

### Volume Optimization

```bash
# Monitor volume usage
docker system df -v

# Clean up unused volumes
docker volume prune
```

## 🔒 Security Notes

- **Nacos**: JWT authentication enabled with custom secret
- **Grafana**: Change default admin password in production
- **Prometheus**: Consider adding authentication for production
- **Loki**: No authentication by default - add reverse proxy if needed

## 📝 Development Notes

### Network Architecture
- All services communicate via Docker internal network
- External access only through mapped ports
- Service discovery via container names

### Data Persistence
- All critical data stored in named Docker volumes
- Volumes survive container restarts
- Regular backup recommended for production

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `docker compose up -d`
5. Submit a pull request

## 📄 License

This infrastructure stack is provided as-is for development and learning purposes.
