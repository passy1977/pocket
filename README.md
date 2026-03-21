# 🔐 Pocket - Secure Credential Management Platform

[![Java](https://img.shields.io/badge/Java-21+-blue.svg)](https://www.oracle.com/java/)
[![Rust](https://img.shields.io/badge/Rust-1.70+-orange.svg)](https://www.rust-lang.org/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4-green.svg)](https://spring.io/projects/spring-boot)
[![Docker](https://img.shields.io/badge/Docker%20%7C%20Podman-Ready-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Pocket** is a comprehensive, enterprise-grade secure credential and password management platform designed for both individual users. It provides local persistence with remote synchronization capabilities, ensuring your sensitive data is always encrypted, accessible, and synchronized across all your devices.

---

## 📋 Table of Contents

- [🌟 Overview](#overview)
- [✨ Key Features](#key-features)
- [🏗️ Architecture](#architecture)
- [🔧 System Components](#system-components)
- [📋 Requirements](#requirements)
- [🚀 Quick Start](#quick-start)
- [� Installation](#installation)
- [⚙️ Configuration](#configuration)
- [📖 Usage](#usage)
- [🔐 Security](#security)
- [🚢 Deployment](#deployment)
- [📊 Monitoring & Maintenance](#monitoring--maintenance)
- [🔍 Troubleshooting](#troubleshooting)
- [🤝 Contributing](#contributing)
- [📄 License](#license)
- [🔗 Related Projects](#related-projects)
- [📞 Support](#support)

---

## 🌟 Overview

Pocket is a full-stack security platform that combines multiple technologies to deliver a robust, scalable, and highly secure credential management solution:

- **Backend Services**: Built with Java 21 and Spring Boot 4 for enterprise-grade reliability
- **Web Interface**: High-performance Rust-based web server using Actix Web
- **Native Library**: C++ core library for maximum performance and cross-platform compatibility
- **Multiple Clients**: Support for web browsers, iOS devices, and command-line interfaces
- **Containerized Deployment**: Full Docker and Podman support for easy deployment and scaling

The platform is designed with security as the primary concern, implementing end-to-end encryption, secure session management, advanced rate limiting, and protection against common web vulnerabilities.

---

## ✨ Key Features

### 🔒 Security First
- **End-to-End Encryption**: RSA + AES-CBC hybrid encryption for maximum security
- **Cryptographically Secure Sessions**: SHA256-based session ID generation with multiple entropy sources
- **Advanced Rate Limiting**: Protection against brute force, DoS, and credential stuffing attacks
- **Spring Security Integration**: Industry-standard authentication and authorization
- **No Plaintext Storage**: All credentials encrypted at rest and in transit

### 🚀 Performance & Scalability
- **Multi-Language Architecture**: Java for business logic, Rust for web serving, C++ for core operations
- **Connection Pooling**: Optimized database connections for high throughput
- **Efficient Resource Management**: Thread-safe architecture with automatic cleanup
- **Horizontal Scaling**: Container-based deployment supports load balancing
- **Caching Strategies**: Smart caching for frequently accessed data

### 🌐 Cross-Platform Support
- **Web Application**: Modern responsive web interface
- **iOS Application**: Native iOS client for iPhone and iPad
- **CLI Tools**: Command-line utilities for automation and administration
- **Container Support**: Docker and Podman for deployment flexibility
- **Multiple Databases**: MySQL, MariaDB support

### 📊 Enterprise Features
- **Health Monitoring**: Built-in health checks and status endpoints
- **Comprehensive Logging**: Detailed application and access logs
- **Metrics & Analytics**: Spring Boot Actuator integration
- **Backup & Recovery**: Automated backup capabilities
- **User Management**: Advanced user and device management tools
- **Session Management**: Configurable session timeouts and policies

### 🔄 Synchronization
- **Multi-Device Sync**: Keep credentials synchronized across all devices
- **Conflict Resolution**: Intelligent handling of concurrent updates
- **Offline Support**: Local caching with automatic sync when online
- **Version Control**: Track changes to credential data

---

## 🏗️ Architecture

Pocket follows a modern multi-tier architecture designed for security, performance, and maintainability:

```
           ┌──────────────┐
           │   Web App    │
           │  (Browser)   │
           └──────┬───────┘
                  │
                  ▼
┌────────────────────────────────┐          ┌──────────────┐
│   Pocket Web Backend (Rust)    │          │  iOS Client  │
│  • Rate Limiting               │          │  (Native)    │
│  • Session Management          │          │              │
│  • Static File Serving         │          │              │
│  • CORS & Security Headers     │          │              │
│  • C++ Bridge Interface        │          │              │
│  Port: 8080                    │          │              │
└─────────────────┬──────────────┘          └────────┬─────┘
                  │                                  │
                  └──────────────┬───────────────────┘
                                 ▼
        ┌────────────────────────────────────────────┐
        │     Pocket Lib (C++ Core Library)          │
        │  • Cryptographic Operations (RSA/AES)      │
        │  • Performance-Critical Code               │
        │  • User/Field/Group Models                 │
        │  • Business Logic Bridge                   │
        │  • Cross-Platform Support                  │
        └────────────────────┬───────────────────────┘
                             ▼
        ┌────────────────────────────────────────────┐
        │   Pocket Backend (Java/Spring Boot)        │
        │  • REST API Endpoints                      │
        │  • Authentication & Authorization          │
        │  • Data Persistence                        │
        │  • Session Validation                      │
        │  • User/Field/Group Management             │
        │  Port: 8081                                │
        └────────────────────┬───────────────────────┘
                             ▼
        ┌────────────────────────────────────────────┐
        │      Database Layer (MariaDB)              │
        │  • User Data                               │
        │  • Encrypted Credentials                   │
        │  • Session Store                           │
        │  • Audit Logs                              │
        │  Port: 3306                                │
        └────────────────────────────────────────────┘
```

### Component Communication Flow

1. **Web App → Web Backend**: Browser clients connect to Rust server (port 8080) for web interface
2. **iOS Client → Pocket Lib**: iOS native app communicates directly with C++ library
3. **Web Backend → Pocket Lib**: Rust server invokes C++ library via bridge interface
4. **Rate Limiting & Security**: Web backend applies rate limits, session validation, and security headers
5. **C++ Library Processing**: Pocket Lib handles:
   - Cryptographic operations (RSA, AES-CBC encryption/decryption)
   - Data validation and business logic
   - User/Field/Group model management
   - Cross-platform compatibility layer
6. **Backend Communication**: Pocket Lib communicates with Java backend via REST APIs (port 8081)
7. **Business Logic**: Spring Boot services handle:
   - Authentication and authorization
   - Data persistence and retrieval
   - Session management and validation
8. **Database Operations**: Encrypted data persisted to MariaDB (port 3306)
9. **Response Chain**: Data flows back through Pocket Lib → Client (Web Backend or iOS)

---

## 🔧 System Components

### 1. Pocket Backend (Java/Spring Boot)
**Location**: `pocket-backend/`

The core business logic layer built with Spring Boot 4 and Java 21.

**Key Technologies**:
- Spring Boot 4
- Spring Security
- Spring Data JPA
- MariaDB Connector
- Jackson (JSON)
- Java 21 LTS

**Features**:
- RESTful API endpoints
- User authentication and authorization
- Field and group management
- Session management
- Data encryption/decryption
- Health monitoring endpoints
- Actuator for metrics

**Default Port**: 8081

### 2. Pocket Web Backend (Rust/Actix)
**Location**: `pocket-web-backend/`

High-performance web server and reverse proxy built with Rust and Actix Web.

**Key Technologies**:
- Rust 1.70+ (2024 edition)
- Actix Web 4
- Actix CORS
- Async/Await
- Tokio Runtime

**Features**:
- Advanced rate limiting (IP + session-based)
- Cryptographically secure session ID generation
- Static file serving
- CORS configuration
- Request/response logging
- Multi-threaded architecture
- Zero-copy static file serving

**Default Port**: 8080

### 3. Pocket Lib (C++ Library)
**Location**: `pocket-web-backend/bridge/pocket-lib/`

Core C++ library providing performance-critical operations and cross-platform compatibility.

**Key Technologies**:
- Modern C++ (C++17/20)
- CMake build system
- nlohmann/json
- TinyXML2

**Features**:
- High-performance cryptographic operations
- Data structure management
- Cross-platform compatibility
- Thread-safe implementations
- Easy integration via CMake

### 4. Database (MariaDB)
**Container**: `pocket-db`

Persistent storage for all application data.

**Configuration**:
- Database: pocket5
- Character Set: utf8mb4
- Collation: utf8mb4_unicode_ci
- InnoDB Engine
- Connection Pool: 200 max connections

**Default Port**: 3306

---

## 📋 Requirements

### Development Environment

#### Backend Development (Java)
- **Java Development Kit (JDK)**: 21+ (LTS recommended)
- **Maven**: 3.8+ for dependency management
- **IDE**: IntelliJ IDEA, Eclipse, or VS Code with Java extensions

#### Web Backend Development (Rust)
- **Rust**: 1.70 or later (2024 edition)
- **Cargo**: Latest version (included with Rust)
- **CMake**: 3.15+ for building C++ bridge
- **Clang**: For C++ binding generation

#### C++ Library Development
- **Compiler**: GCC 9+ or Clang 10+
- **CMake**: 3.15+
- **Build Tools**: make, pkg-config
- **Libraries**: OpenSSL, libcurl, sqlite3

### Production Environment

#### Required Software
- **Container Runtime**: Docker 24.0+ **OR** Podman 4.0+
- **Docker Compose**: 2.0+ (or podman-compose)
- **Database**: MariaDB 10.6+ or MySQL 8.0+

#### System Resources
- **CPU**: 2+ cores (4+ recommended)
- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 20GB+ available disk space
- **Network**: Open ports 8080, 8081, 3306

#### Operating System
- **Linux**: Ubuntu 20.04+, Debian 12+, RHEL 8+, Fedora 35+
- **macOS**: 11+ (Big Sur or later)
- **Windows**: 10+ with WSL2 for Docker/Podman

### Optional Tools
- **Nginx**: For reverse proxy and SSL termination
- **Prometheus**: For metrics collection
- **Grafana**: For metrics visualization
- **ELK Stack**: For centralized logging

---

## 🚀 Quick Start

The fastest way to get Pocket up and running is using the automated setup script:

### 1. Clone the Repository

```bash
git clone --recursive https://github.com/passy1977/pocket.git
cd pocket
```

**Important**: Use `--recursive` to include all submodules (pocket-backend, pocket-web-backend, pocket-lib, pocket-web-frontend).

### 2. Run Interactive Setup

```bash
# Make the setup script executable
chmod +x setup_environment.sh

# Run the interactive configuration wizard
./setup_environment.sh
```

The setup script is **interactive** and will ask you configuration questions:
- 🔍 **Container Runtime**: Docker or Podman detection
- 🔐 **Security Settings**: Generate or provide encryption keys and passwords
- 🌐 **Network Configuration**: Host, ports, and CORS settings
- 📁 **Storage Options**: Docker volumes configuration

The script will automatically:
- ✅ Generate secure passwords and encryption keys (AES_CBC_IV, admin password)
- ✅ Create environment configuration (`.env` file)
- ✅ Set up Docker volumes and network
- ✅ Generate management scripts (`start_pocket.sh`, `stop_pocket.sh`, `clean_pocket.sh`, `clean_images.sh`)

### 3. Start the Services

After setup completes, start all services:

```bash
./start_pocket.sh
```

This will:
- 🏗️ Build Docker images for all components
- 🗄️ Start MariaDB database
- ☕ Start Pocket Backend (Java/Spring Boot)
- 🦀 Start Pocket Web Backend (Rust/Actix)
- 🛠️ Install CLI management tools
- ✅ Perform health checks

### 4. Verify Installation

```bash
# Check running containers
docker ps
# or
podman ps

# Check backend health
curl http://localhost:8081/actuator/health

# Check web backend health
curl http://localhost:8080/health

# Access the web application
# Open your browser and navigate to:
http://localhost:8080
```

### 5. Login

Default credentials (change immediately after first login):
- **Username**: admin
- **Password**: (generated during setup, check .env file)

---

## � Installation

For manual installation or custom deployment scenarios:

### Building from Source

#### 1. Build Pocket Backend (Java)

```bash
cd pocket-backend

# Configure environment
export DB_USERNAME="pocket_user"
export DB_PASSWORD="your_secure_password"
export AES_CBC_IV="your_16_char_iv_"  # Exactly 16 characters
export ADMIN_USER="admin"
export ADMIN_PASSWD="your_admin_password"

# Build with Maven
mvn clean package -DskipTests

# Run locally
java -jar target/pocket-backend-5.0.0.jar
```

#### 2. Build Pocket Web Backend (Rust)

```bash
cd pocket-web-backend

# Update submodules
git submodule update --init --recursive

# Build the project
cargo build --release

# Run locally
POCKET_HOST=0.0.0.0 \
POCKET_PORT=8080 \
POCKET_MAX_THREADS=4 \
POCKET_SESSION_EXPIRATION=300 \
./target/release/pocket-web-backend
```

#### 3. Build Pocket Lib (C++)

```bash
cd pocket-web-backend/bridge/pocket-lib

# Create build directory
mkdir build && cd build

# Configure with CMake
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTS=OFF

# Build
make -j$(nproc)

# Install
sudo make install
```

### Docker Build

#### Build Images Individually

```bash
# Build backend
docker build -t pocket-backend:5.0.0 ./pocket-backend

# Build web backend
docker build -t pocket-web-backend:5.0.0 ./pocket-web-backend

# Or use Podman
podman build -t pocket-backend:5.0.0 ./pocket-backend
podman build -t pocket-web-backend:5.0.0 ./pocket-web-backend
```

#### Using Docker Compose

```bash
# Build all services
docker compose build

# Or with Podman
podman-compose build
```

---

## ⚙️ Configuration

### Environment Variables

The `.env` file is automatically generated by `setup_environment.sh`. For manual configuration, create a `.env` file in the project root:

```bash
# ===========================================
# POCKET FULL STACK CONFIGURATION
# ===========================================
# Generated on: <timestamp>
# Container Runtime: docker | podman

# ===========================================
# DATABASE CONFIGURATION
# ===========================================
DB_ROOT_PASSWORD=your_secure_root_password_here
DB_USERNAME=pocket_user
DB_PASSWORD=your_secure_user_password_here

# ===========================================
# BACKEND CONFIGURATION
# ===========================================
# Security Configuration
AES_CBC_IV=your_16_char_iv_  # CRITICAL: Exactly 16 characters
ADMIN_USER=admin@example.com
ADMIN_PASSWD=your_secure_admin_password_here

# Server Configuration
SERVER_URL=http://localhost:8081
SERVER_PORT=8081
CORS_ADDITIONAL_ORIGINS=
CORS_ENABLE_STRICT=false
CORS_HEADER_TOKEN=X-Requested-With

# JVM Configuration
JVM_MAX_MEMORY=512m
JVM_MIN_MEMORY=256m

# ===========================================
# WEB APP CONFIGURATION
# ===========================================
POCKET_HOST=0.0.0.0
POCKET_PORT=8080
BACKEND_URL=http://pocket-backend:8081
POCKET_MAX_THREADS=4
POCKET_SESSION_EXPIRATION=300
CORS_ALLOWED_ORIGINS=http://localhost:8080
POCKET_ENABLE_LOGS=0  # 1 to enable logs in release builds

# ===========================================
# GENERAL CONFIGURATION
# ===========================================
LOG_LEVEL=INFO

# ===========================================
# INTERNAL CONFIGURATION (DO NOT MODIFY)
# ===========================================
COMPOSE_PROJECT_NAME=pocket
NETWORK_NAME=pocket-network
VOLUMES_PATH=./docker-volumes
```

**Note**: The `setup_environment.sh` script will generate secure random values for all passwords and keys automatically.

### Database Configuration

Edit `docker-volumes/pocket5-config.yaml`:

```yaml
database:
  host: pocket-db
  port: 3306
  name: pocket5
  username: ${DB_USERNAME}
  password: ${DB_PASSWORD}
  pool:
    maxSize: 20
    minIdle: 5
    connectionTimeout: 30000
```

### Rate Limiting Configuration

The web backend includes built-in rate limiting. To customize, edit the Rust source:

**File**: `pocket-web-backend/src/services/rate_limiter.rs`

```rust
// Critical endpoints
("/v5/pocket/login", RateLimit::new(5, 300)),           // 5 per 5 minutes
("/v5/pocket/registration", RateLimit::new(3, 3600)),   // 3 per hour
("/v5/pocket/change_passwd", RateLimit::new(3, 3600)),  // 3 per hour
("/v5/pocket/heartbeat", RateLimit::new(6, 60)),        // 6 per minute
```

### CORS Configuration

Configure allowed origins in the `.env` file:

```bash
# Development (allow all)
CORS_ALLOWED_ORIGINS=*

# Production (specific domains)
CORS_ALLOWED_ORIGINS=https://app.example.com,https://www.example.com
```

---

## 📖 Usage

### Web Application

1. **Open Browser**: Navigate to `http://localhost:8080`
2. **Login**: Use your admin credentials
3. **Create Fields**: Store credentials, passwords, notes
4. **Create Groups**: Organize fields into logical groups
5. **Sync**: Data automatically syncs across devices

### CLI Tools

The installation includes two command-line tools:

#### pocket-user - User Management

```bash
# List all users
pocket-user list

# Create a new user
pocket-user create --username john --email john@example.com

# Delete a user
pocket-user delete --username john

# Change user password
pocket-user passwd --username john
```

#### pocket-device - Device Management

```bash
# List all devices
pocket-device list

# Register a new device
pocket-device register --name "iPhone" --user john

# Revoke device access
pocket-device revoke --device-id abc123

# List devices for user
pocket-device list --user john
```

### API Usage

#### Authentication

```bash
# Login
curl -X POST http://localhost:8080/v5/pocket/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "your_password"
  }'
```

#### Create Field

```bash
# Create a new credential field
curl -X POST http://localhost:8080/v5/pocket/field \
  -H "Content-Type: application/json" \
  -H "Session-ID: your_session_id" \
  -d '{
    "name": "Gmail",
    "username": "user@example.com",
    "password": "encrypted_password",
    "url": "https://gmail.com"
  }'
```

#### Get User Data

```bash
# Retrieve all user data
curl -X POST http://localhost:8080/v5/pocket/home \
  -H "Content-Type: application/json" \
  -H "Session-ID: your_session_id" \
  -d '{
    "sessionId": "your_session_id"
  }'
```

See the full API documentation in the individual component READMEs.

---

## 🔐 Security

### Encryption

**At Rest**:
- All credentials encrypted with AES-256-CBC
- User passwords hashed with bcrypt
- Encryption keys never stored in plaintext

**In Transit**:
- HTTPS/TLS 1.3 for all communications
- Perfect Forward Secrecy (PFS)
- Strong cipher suites only

### Session Security

- Cryptographically secure session IDs (SHA256)
- Multiple entropy sources (timestamp, PID, system random)
- Configurable session timeouts
- Automatic session cleanup

### Rate Limiting

Protection against various attacks:

| Endpoint | Limit | Window | Purpose |
|----------|-------|--------|---------|
| Login | 5 requests | 5 minutes | Prevent brute force |
| Registration | 3 requests | 1 hour | Prevent abuse |
| Password Change | 3 requests | 1 hour | Account protection |
| General API | 1000 requests | 1 hour | DoS prevention |

### Best Practices

1. **Change Default Credentials**: Immediately after installation
2. **Use Strong Passwords**: Minimum 12 characters with complexity
3. **Enable HTTPS**: Use SSL/TLS certificates in production
4. **Regular Updates**: Keep all components up to date
5. **Firewall Rules**: Restrict access to necessary ports only
6. **Backup Encryption**: Encrypt database backups
7. **Audit Logs**: Regularly review access logs
8. **Two-Factor Authentication**: Coming in future release

---

## 🚢 Deployment

### Production Deployment with Docker Compose

```bash
# 1. Configure production environment
cp .env.example .env.production
nano .env.production

# 2. Build production images
docker compose -f compose.yaml build

# 3. Start services
docker compose -f compose.yaml up -d

# 4. Verify deployment
docker compose ps
docker compose logs -f
```

### Deployment with Nginx Reverse Proxy

Create `/etc/nginx/sites-available/pocket`:

```nginx
upstream pocket_backend {
    server localhost:8080;
}

server {
    listen 80;
    server_name pocket.example.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name pocket.example.com;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/pocket.crt;
    ssl_certificate_key /etc/ssl/private/pocket.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        proxy_pass http://pocket_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable and restart:

```bash
sudo ln -s /etc/nginx/sites-available/pocket /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### Kubernetes Deployment

Example Kubernetes manifests are available in the `k8s/` directory (coming soon).

---

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# Backend health
curl http://localhost:8081/actuator/health

# Web backend health
curl http://localhost:8080/health

# Database health
docker exec pocket-db mysqladmin ping -h localhost
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f pocket-backend
docker compose logs -f pocket-web-backend

# Application logs
tail -f docker-volumes/pocket-logs/application.log
tail -f docker-volumes/pocket-web-logs/application.log
```

### Backup

```bash
# Database backup
docker exec pocket-db mysqldump \
  -u root -p${DB_ROOT_PASSWORD} \
  pocket5 > backup-$(date +%Y%m%d).sql

# Volume backup
docker run --rm \
  -v pocket-db-data:/data \
  -v $(pwd)/backups:/backup \
  ubuntu tar czf /backup/db-$(date +%Y%m%d).tar.gz /data
```

### Restore

```bash
# Restore database
docker exec -i pocket-db mysql \
  -u root -p${DB_ROOT_PASSWORD} \
  pocket5 < backup-20260321.sql

# Restore volume
docker run --rm \
  -v pocket-db-data:/data \
  -v $(pwd)/backups:/backup \
  ubuntu tar xzf /backup/db-20260321.tar.gz -C /
```

### Metrics

Access Spring Boot Actuator metrics:

```bash
# General metrics
curl http://localhost:8081/actuator/metrics

# JVM memory
curl http://localhost:8081/actuator/metrics/jvm.memory.used

# HTTP requests
curl http://localhost:8081/actuator/metrics/http.server.requests
```

---

## � Troubleshooting

### Common Issues

#### 1. Container Won't Start

**Problem**: Container exits immediately after starting

**Solution**:
```bash
# Check logs
docker compose logs pocket-backend

# Verify environment variables
docker compose config

# Check database connectivity
docker compose exec pocket-backend ping pocket-db
```

#### 2. Database Connection Failed

**Problem**: Backend can't connect to database

**Solution**:
```bash
# Verify database is running
docker compose ps pocket-db

# Check database logs
docker compose logs pocket-db

# Test connection
docker compose exec pocket-backend \
  mysql -h pocket-db -u pocket_user -p
```

#### 3. Port Already in Use

**Problem**: Cannot bind to port 8080 or 8081

**Solution**:
```bash
# Find process using port
sudo lsof -i :8080
sudo lsof -i :8081

# Change port in .env file
POCKET_PORT=8090
SERVER_PORT=8091

# Restart services
docker compose down
docker compose up -d
```

#### 4. Rate Limiting Issues

**Problem**: Getting 429 Too Many Requests errors

**Solution**:
- Wait for the rate limit window to expire
- Check your IP address isn't triggering limits incorrectly
- Adjust rate limits in source code if needed for your use case

#### 5. Session Expired Errors

**Problem**: Frequent session expiration

**Solution**:
```bash
# Increase session timeout in .env
POCKET_SESSION_EXPIRATION=900  # 15 minutes

# Restart web backend
docker compose restart pocket-web-backend
```

### Debug Mode

Enable debug logging:

```bash
# In .env file
LOG_LEVEL=DEBUG

# Restart services
docker compose restart
```

### Reset Everything

```bash
# Stop all services
./stop_pocket.sh

# Clean images
./clean_images.sh

# Full cleanup (removes all data!)
./clean_pocket.sh

# Start fresh
./setup_environment.sh
./start_pocket.sh
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the Repository**: Create your own fork on GitHub
2. **Create a Branch**: `git checkout -b feature/your-feature-name`
3. **Make Changes**: Follow coding standards and add tests
4. **Commit**: Use clear, descriptive commit messages
5. **Push**: `git push origin feature/your-feature-name`
6. **Pull Request**: Submit a PR with a detailed description

### Coding Standards

- **Java**: Follow Google Java Style Guide
- **Rust**: Use `cargo fmt` and `cargo clippy`
- **C++**: Follow Modern C++ guidelines
- **Documentation**: Update README files for any changes

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Related Projects

The Pocket ecosystem consists of multiple components and client applications:

### Core Components

- **[Pocket Backend](https://github.com/passy1977/pocket-backend)** - Java/Spring Boot backend service providing REST APIs, authentication, and business logic
- **[Pocket Web Backend](https://github.com/passy1977/pocket-web-backend)** - Rust/Actix web server with rate limiting and session management
- **[Pocket Lib](https://github.com/passy1977/pocket-lib)** - C++ core library for performance-critical operations and cryptography

### Client Applications

- **[Pocket Web Frontend](https://github.com/passy1977/pocket-web-frontend)** - Modern web interface for browser-based access
- **[Pocket iOS](https://github.com/passy1977/pocket-ios)** - Native iOS application for iPhone and iPad
- **[Pocket CLI](https://github.com/passy1977/pocket-cli)** - Command-line tools for user and device management

### Dependencies

- **[nlohmann/json](https://github.com/nlohmann/json)** - Modern C++ JSON library
- **[TinyXML2](https://github.com/leethomason/tinyxml2)** - Lightweight XML parser
- **[Google Test](https://github.com/google/googletest)** - C++ testing framework

---

## 📞 Support

For questions, issues, or feature requests:

- **Issues**: Open an issue on the appropriate repository
- **Documentation**: Check component-specific README files
- **Security**: Report security vulnerabilities privately

---

**Made with ❤️ for secure credential management**
