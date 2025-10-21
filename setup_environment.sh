#!/bin/bash

# Pocket Full Stack Setup Script
# This script configures both Pocket Backend (Java) and Pocket Web Backend (Rust)
# Prepares volumes, copies necessary files, and generates secure configuration
# Automatically detects and uses Podman or Docker

set -e  # Exit on any error

# Configuration
NETWORK=pocket-network
ENV_FILE=".env"
VOLUMES_DIR="docker_volumes"
NGINX_DIR="nginx"
SCRIPTS_DIR="scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_config() { echo -e "${PURPLE}[CONFIG]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Banner function
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    POCKET FULL STACK SETUP                  ║"
    echo "║                                                              ║"
    echo "║  🚀 Java Backend + Rust Web Backend + MariaDB + Nginx       ║"
    echo "║  🔒 Secure configuration with auto-generated secrets        ║"
    echo "║  🐳 Docker/Podman compatible                                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Detect container runtime (Podman or Docker)
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        CONTAINER_RUNTIME="podman"
        log_info "Detected Podman as container runtime"
    elif command -v docker &> /dev/null; then
        CONTAINER_RUNTIME="docker"
        log_info "Detected Docker as container runtime"
    else
        log_error "Neither Podman nor Docker found. Please install one of them."
        exit 1
    fi
    
    # Check compose command
    if [ "$CONTAINER_RUNTIME" = "podman" ]; then
        if ! command -v podman-compose &> /dev/null; then
            log_error "podman-compose is not installed. Please install it: pip install podman-compose"
            exit 1
        fi
        COMPOSE_CMD="podman-compose"
    else
        if ! docker compose version &> /dev/null; then
            log_error "Docker Compose is not installed. Please install Docker Compose first."
            exit 1
        fi
        COMPOSE_CMD="docker compose"
    fi
}

# Function to generate random secure passwords
generate_password() {
    local length=${1:-32}
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-$length
}

# Function to generate AES IV (16 characters)
generate_aes_iv() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

# Function to validate AES IV
validate_aes_iv() {
    local iv="$1"
    if [[ ${#iv} -ne 16 ]]; then
        log_error "AES CBC IV must be exactly 16 characters long"
        return 1
    fi
    if [[ ! "$iv" =~ ^[A-Za-z0-9_-]+$ ]]; then
        log_error "AES CBC IV contains invalid characters. Use only A-Z, a-z, 0-9, _, -"
        return 1
    fi
    return 0
}

# Function to validate port number
validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Invalid port number: $port"
        return 1
    fi
    return 0
}

# Function to setup container network
setup_network() {
    log_step "Setting up $CONTAINER_RUNTIME network '$NETWORK'..."
    
    if $CONTAINER_RUNTIME network inspect $NETWORK &> /dev/null; then
        log_success "Network '$NETWORK' already exists"
    else
        log_info "Creating network '$NETWORK'..."
        $CONTAINER_RUNTIME network create $NETWORK
        log_success "Network '$NETWORK' created"
    fi
}

# Function to setup directories and volumes
setup_directories() {
    log_step "Setting up directories and volumes..."
    
    # Create main volumes directory
    if [ ! -d "$VOLUMES_DIR" ]; then
        mkdir -p "$VOLUMES_DIR"
        log_success "Created $VOLUMES_DIR directory"
    fi
    
    # Create individual volume directories
    local volumes=(
        "pocket_db_data"
        "pocket_logs"
        "pocket_web_logs"
        "nginx_logs"
        "nginx_ssl"
        "nginx_config"
    )
    
    for volume in "${volumes[@]}"; do
        local vol_path="$VOLUMES_DIR/$volume"
        if [ ! -d "$vol_path" ]; then
            mkdir -p "$vol_path"
            log_success "Created volume directory: $vol_path"
        fi
    done
    
    # Set appropriate permissions
    chmod 755 "$VOLUMES_DIR"
    chmod 755 "$VOLUMES_DIR"/*
    
    # Set specific permissions for database directory
    if [ -d "$VOLUMES_DIR/pocket_db_data" ]; then
        chmod 777 "$VOLUMES_DIR/pocket_db_data"  # MariaDB needs write access
    fi
    
    log_success "All volume directories created and configured"
}

# Function to copy necessary files
copy_configuration_files() {
    log_step "Copying configuration files..."
    
    # Copy database initialization script
    if [ -f "pocket-backend/scripts/pocket5.sql" ]; then
        cp "pocket-backend/scripts/pocket5.sql" "$VOLUMES_DIR/"
        log_success "Copied database initialization script"
    elif [ -f "scripts/pocket5.sql" ]; then
        cp "scripts/pocket5.sql" "$VOLUMES_DIR/"
        log_success "Copied database initialization script"
    else
        log_warning "Database initialization script not found. You may need to copy it manually."
    fi
    
    # Copy pocket5-config.yaml if exists
    if [ -f "pocket-backend/scripts/pocket5-config.yaml" ]; then
        cp "pocket-backend/scripts/pocket5-config.yaml" "$VOLUMES_DIR/"
        log_success "Copied pocket5-config.yaml"
    elif [ -f "scripts/pocket5-config.yaml" ]; then
        cp "scripts/pocket5-config.yaml" "$VOLUMES_DIR/"
        log_success "Copied pocket5-config.yaml"
    else
        log_info "pocket5-config.yaml not found, will use default configuration"
    fi
    
    # Setup nginx configuration
    setup_nginx_config
}

# Function to setup nginx configuration
setup_nginx_config() {
    log_step "Setting up Nginx configuration..."
    
    # Create nginx config directory if it doesn't exist
    if [ ! -d "$NGINX_DIR" ]; then
        mkdir -p "$NGINX_DIR"
    fi
    
    # Create nginx.conf if it doesn't exist
    if [ ! -f "$NGINX_DIR/nginx.conf" ]; then
        cat > "$NGINX_DIR/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private must-revalidate;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Upstream servers
    upstream pocket_backend {
        server pocket-backend:8081;
    }
    
    upstream pocket_web_backend {
        server pocket-web-backend:8080;
    }
    
    # Main server block
    server {
        listen 80;
        server_name localhost;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        
        # Java Backend API
        location /api/ {
            proxy_pass http://pocket_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        # Rust Web Backend
        location /web/ {
            proxy_pass http://pocket_web_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        # Health checks
        location /health {
            proxy_pass http://pocket_web_backend/health;
            proxy_set_header Host $host;
        }
        
        location /actuator/health {
            proxy_pass http://pocket_backend/actuator/health;
            proxy_set_header Host $host;
        }
        
        # Default location
        location / {
            proxy_pass http://pocket_web_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF
        log_success "Created nginx.conf"
    else
        log_info "nginx.conf already exists, skipping creation"
    fi
    
    # Copy nginx config to volume
    cp "$NGINX_DIR/nginx.conf" "$VOLUMES_DIR/nginx_config/"
    log_success "Copied nginx configuration to volume"
}

# Function to collect database configuration
collect_database_config() {
    log_config "📊 Database Configuration"
    echo "=========================="
    
    if [ -z "$DB_ROOT_PASSWORD" ]; then
        read -p "Generate secure database root password automatically? [Y/n]: " auto_db_pass
        if [[ "$auto_db_pass" =~ ^[Nn]$ ]]; then
            while true; do
                read -s -p "Enter MariaDB root password: " DB_ROOT_PASSWORD
                echo
                if [ ${#DB_ROOT_PASSWORD} -ge 8 ]; then
                    break
                else
                    log_error "Password must be at least 8 characters long"
                fi
            done
        else
            DB_ROOT_PASSWORD=$(generate_password 32)
            log_success "Generated secure database root password"
        fi
    fi
    
    if [ -z "$DB_USERNAME" ]; then
        read -p "Database username [pocket_user]: " DB_USERNAME
        DB_USERNAME=${DB_USERNAME:-pocket_user}
    fi
    
    if [ -z "$DB_PASSWORD" ]; then
        read -p "Generate secure database user password automatically? [Y/n]: " auto_user_pass
        if [[ "$auto_user_pass" =~ ^[Nn]$ ]]; then
            while true; do
                read -s -p "Enter database user password: " DB_PASSWORD
                echo
                if [ ${#DB_PASSWORD} -ge 8 ]; then
                    break
                else
                    log_error "Password must be at least 8 characters long"
                fi
            done
        else
            DB_PASSWORD=$(generate_password 32)
            log_success "Generated secure database user password"
        fi
    fi
}

# Function to collect Java backend configuration
collect_java_backend_config() {
    log_config "☕ Java Backend Configuration"
    echo "============================"
    
    # Security configuration
    if [ -z "$AES_CBC_IV" ]; then
        read -p "Generate secure AES CBC IV automatically? [Y/n]: " auto_aes
        if [[ "$auto_aes" =~ ^[Nn]$ ]]; then
            while true; do
                read -p "Enter AES CBC IV (exactly 16 characters): " AES_CBC_IV
                if validate_aes_iv "$AES_CBC_IV"; then
                    break
                fi
            done
        else
            AES_CBC_IV=$(generate_aes_iv)
            log_success "Generated secure AES CBC IV"
        fi
    fi
    
    if [ -z "$ADMIN_USER" ]; then
        read -p "Admin username [admin]: " ADMIN_USER
        ADMIN_USER=${ADMIN_USER:-admin}
    fi
    
    if [ -z "$ADMIN_PASSWD" ]; then
        read -p "Generate secure admin password automatically? [Y/n]: " auto_admin_pass
        if [[ "$auto_admin_pass" =~ ^[Nn]$ ]]; then
            while true; do
                read -s -p "Enter admin password: " ADMIN_PASSWD
                echo
                if [ ${#ADMIN_PASSWD} -ge 8 ]; then
                    break
                else
                    log_error "Password must be at least 8 characters long"
                fi
            done
        else
            ADMIN_PASSWD=$(generate_password 32)
            log_success "Generated secure admin password"
        fi
    fi
    
    # Server configuration
    if [ -z "$SERVER_URL" ]; then
        read -p "Server URL [http://localhost:8081]: " SERVER_URL
        SERVER_URL=${SERVER_URL:-http://localhost:8081}
    fi
    
    if [ -z "$SERVER_PORT" ]; then
        while true; do
            read -p "Java Backend port [8081]: " SERVER_PORT
            SERVER_PORT=${SERVER_PORT:-8081}
            if validate_port "$SERVER_PORT"; then
                break
            fi
        done
    fi
    
    if [ -z "$CORS_ADDITIONAL_ORIGINS" ]; then
        read -p "Additional CORS origins (comma-separated) []: " CORS_ADDITIONAL_ORIGINS
    fi
    
    # JVM configuration
    if [ -z "$JVM_MAX_MEMORY" ]; then
        read -p "JVM Max Memory [512m]: " JVM_MAX_MEMORY
        JVM_MAX_MEMORY=${JVM_MAX_MEMORY:-512m}
    fi
    
    if [ -z "$JVM_MIN_MEMORY" ]; then
        read -p "JVM Min Memory [256m]: " JVM_MIN_MEMORY
        JVM_MIN_MEMORY=${JVM_MIN_MEMORY:-256m}
    fi
}

# Function to collect Rust web backend configuration
collect_rust_backend_config() {
    log_config "🦀 Rust Web Backend Configuration"
    echo "================================="
    
    if [ -z "$WEB_BACKEND_ADDRESS" ]; then
        read -p "Web Backend Address [0.0.0.0]: " WEB_BACKEND_ADDRESS
        WEB_BACKEND_ADDRESS=${WEB_BACKEND_ADDRESS:-0.0.0.0}
    fi
    
    if [ -z "$WEB_BACKEND_PORT" ]; then
        while true; do
            read -p "Web Backend Port [8080]: " WEB_BACKEND_PORT
            WEB_BACKEND_PORT=${WEB_BACKEND_PORT:-8080}
            if validate_port "$WEB_BACKEND_PORT"; then
                break
            fi
        done
    fi
    
    if [ -z "$WEB_BACKEND_MAX_THREADS" ]; then
        while true; do
            read -p "Max Threads [2]: " WEB_BACKEND_MAX_THREADS
            WEB_BACKEND_MAX_THREADS=${WEB_BACKEND_MAX_THREADS:-2}
            if [[ "$WEB_BACKEND_MAX_THREADS" =~ ^[0-9]+$ ]] && [ "$WEB_BACKEND_MAX_THREADS" -gt 0 ]; then
                break
            else
                log_error "Max threads must be a positive number"
            fi
        done
    fi
    
    if [ -z "$WEB_BACKEND_SESSION_EXPIRATION" ]; then
        while true; do
            read -p "Session Expiration (seconds) [300]: " WEB_BACKEND_SESSION_EXPIRATION
            WEB_BACKEND_SESSION_EXPIRATION=${WEB_BACKEND_SESSION_EXPIRATION:-300}
            if [[ "$WEB_BACKEND_SESSION_EXPIRATION" =~ ^[0-9]+$ ]] && [ "$WEB_BACKEND_SESSION_EXPIRATION" -gt 0 ]; then
                break
            else
                log_error "Session expiration must be a positive number"
            fi
        done
    fi
}

# Function to collect general configuration
collect_general_config() {
    log_config "⚙️  General Configuration"
    echo "========================"
    
    if [ -z "$LOG_LEVEL" ]; then
        echo "Available log levels: DEBUG, INFO, WARN, ERROR"
        read -p "Log Level [INFO]: " LOG_LEVEL
        LOG_LEVEL=${LOG_LEVEL:-INFO}
    fi
    
    # Nginx configuration
    read -p "Enable Nginx reverse proxy? [Y/n]: " enable_nginx
    if [[ ! "$enable_nginx" =~ ^[Nn]$ ]]; then
        ENABLE_NGINX=true
        log_success "Nginx reverse proxy will be enabled"
    else
        ENABLE_NGINX=false
        log_info "Nginx reverse proxy will be disabled"
    fi
}

# Function to save environment configuration
save_environment_config() {
    log_step "Saving environment configuration..."
    
    cat > "$ENV_FILE" << EOF
# ===========================================
# POCKET FULL STACK CONFIGURATION
# ===========================================
# Generated on: $(date)
# Container Runtime: $CONTAINER_RUNTIME

# ===========================================
# DATABASE CONFIGURATION
# ===========================================
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

# ===========================================
# JAVA BACKEND CONFIGURATION
# ===========================================
# Security Configuration
AES_CBC_IV=$AES_CBC_IV
ADMIN_USER=$ADMIN_USER
ADMIN_PASSWD=$ADMIN_PASSWD

# Server Configuration
SERVER_URL=$SERVER_URL
SERVER_PORT=$SERVER_PORT
CORS_ADDITIONAL_ORIGINS=$CORS_ADDITIONAL_ORIGINS

# JVM Configuration
JVM_MAX_MEMORY=$JVM_MAX_MEMORY
JVM_MIN_MEMORY=$JVM_MIN_MEMORY

# ===========================================
# RUST WEB BACKEND CONFIGURATION
# ===========================================
WEB_BACKEND_ADDRESS=$WEB_BACKEND_ADDRESS
WEB_BACKEND_PORT=$WEB_BACKEND_PORT
WEB_BACKEND_MAX_THREADS=$WEB_BACKEND_MAX_THREADS
WEB_BACKEND_SESSION_EXPIRATION=$WEB_BACKEND_SESSION_EXPIRATION

# ===========================================
# GENERAL CONFIGURATION
# ===========================================
LOG_LEVEL=$LOG_LEVEL
ENABLE_NGINX=$ENABLE_NGINX

# ===========================================
# INTERNAL CONFIGURATION (DO NOT MODIFY)
# ===========================================
COMPOSE_PROJECT_NAME=pocket
NETWORK_NAME=$NETWORK
VOLUMES_PATH=./$VOLUMES_DIR
EOF
    
    # Set restrictive permissions on .env file
    chmod 600 "$ENV_FILE"
    
    log_success "Environment configuration saved to $ENV_FILE"
}

# Function to display configuration summary
display_configuration_summary() {
    log_step "Configuration Summary"
    echo "===================="
    echo
    echo "🗄️  Database:"
    echo "   Username: $DB_USERNAME"
    echo "   Port: 3306"
    echo
    echo "☕ Java Backend:"
    echo "   URL: $SERVER_URL"
    echo "   Port: $SERVER_PORT"
    echo "   Admin User: $ADMIN_USER"
    echo "   JVM Memory: $JVM_MIN_MEMORY - $JVM_MAX_MEMORY"
    echo
    echo "🦀 Rust Web Backend:"
    echo "   Address: $WEB_BACKEND_ADDRESS"
    echo "   Port: $WEB_BACKEND_PORT"
    echo "   Max Threads: $WEB_BACKEND_MAX_THREADS"
    echo "   Session Expiration: $WEB_BACKEND_SESSION_EXPIRATION seconds"
    echo
    echo "⚙️  General:"
    echo "   Log Level: $LOG_LEVEL"
    echo "   Nginx Enabled: $ENABLE_NGINX"
    echo "   Container Runtime: $CONTAINER_RUNTIME"
    echo
    echo "📁 Volumes Directory: $VOLUMES_DIR"
    echo "🌐 Network: $NETWORK"
    echo
}

# Function to create startup script
create_startup_script() {
    log_step "Creating startup script..."
    
    cat > "start_pocket.sh" << EOF
#!/bin/bash

# Pocket Full Stack Startup Script
# Generated by setup_environment.sh

set -e

# Load environment
if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found. Run setup_environment.sh first."
    exit 1
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${BLUE}🚀 Starting Pocket Full Stack...\${NC}"

# Start services
if [ "\$ENABLE_NGINX" = "true" ]; then
    echo -e "\${BLUE}Starting with Nginx reverse proxy...\${NC}"
    $COMPOSE_CMD --profile production up -d
else
    echo -e "\${BLUE}Starting without Nginx...\${NC}"
    $COMPOSE_CMD up -d pocket-db pocket-backend pocket-web-backend
fi

echo -e "\${GREEN}✅ Services started successfully!\${NC}"
echo
echo "📋 Service URLs:"
echo "   Java Backend: \$SERVER_URL"
echo "   Rust Web Backend: http://localhost:\$WEB_BACKEND_PORT"
if [ "\$ENABLE_NGINX" = "true" ]; then
    echo "   Nginx Proxy: http://localhost:80"
fi
echo "   Database: localhost:3306"
echo
echo "🔧 Management commands:"
echo "   View logs: $COMPOSE_CMD logs -f"
echo "   Stop services: $COMPOSE_CMD down"
echo "   Restart: $COMPOSE_CMD restart"
EOF
    
    chmod +x "start_pocket.sh"
    log_success "Created start_pocket.sh"
}

# Function to create stop script
create_stop_script() {
    log_step "Creating stop script..."
    
    cat > "stop_pocket.sh" << EOF
#!/bin/bash

# Pocket Full Stack Stop Script
# Generated by setup_environment.sh

set -e

# Colors
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${BLUE}🛑 Stopping Pocket Full Stack...\${NC}"

# Stop services
$COMPOSE_CMD down

echo -e "\${RED}✅ All services stopped.\${NC}"
EOF
    
    chmod +x "stop_pocket.sh"
    log_success "Created stop_pocket.sh"
}

# Function to display final information
display_final_info() {
    echo
    log_success "🎉 Pocket Full Stack environment setup completed successfully!"
    echo
    echo "📋 What was created:"
    echo "==================="
    echo "✅ Environment configuration (.env)"
    echo "✅ Volume directories ($VOLUMES_DIR/)"
    echo "✅ Nginx configuration ($NGINX_DIR/)"
    echo "✅ Network configuration"
    echo "✅ Startup script (start_pocket.sh)"
    echo "✅ Stop script (stop_pocket.sh)"
    echo
    echo "🚀 Next steps:"
    echo "============="
    echo "1. Build the Docker images:"
    echo "   ./build_docker.sh"
    echo
    echo "2. Start the services:"
    echo "   ./start_pocket.sh"
    echo
    echo "3. Check service status:"
    echo "   $COMPOSE_CMD ps"
    echo
    echo "🔐 Security Notes:"
    echo "================="
    echo "⚠️  Keep your .env file secure and never commit it to version control"
    echo "🔑 All passwords and secrets are stored in .env"
    echo "🛡️  Database and application volumes are in $VOLUMES_DIR/"
    echo
    log_warning "Remember to backup your .env file and $VOLUMES_DIR/ directory!"
}

# Main execution function
main() {
    show_banner
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. Consider using a non-root user for better security."
    fi
    
    # Detect container runtime
    detect_container_runtime
    
    # Load existing configuration if available
    if [ -f "$ENV_FILE" ]; then
        log_info "Loading existing configuration from $ENV_FILE"
        source "$ENV_FILE"
        read -p "Do you want to reconfigure? [y/N]: " reconfigure
        if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
            log_info "Using existing configuration"
            setup_network
            setup_directories
            copy_configuration_files
            create_startup_script
            create_stop_script
            display_configuration_summary
            display_final_info
            exit 0
        fi
    fi
    
    echo
    log_info "🔧 Starting interactive configuration..."
    echo
    
    # Collect all configuration
    collect_database_config
    echo
    collect_java_backend_config
    echo
    collect_rust_backend_config
    echo
    collect_general_config
    echo
    
    # Setup environment
    setup_network
    setup_directories
    copy_configuration_files
    save_environment_config
    create_startup_script
    create_stop_script
    
    # Display summary
    echo
    display_configuration_summary
    display_final_info
}

# Handle script interruption
trap 'log_error "Setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"