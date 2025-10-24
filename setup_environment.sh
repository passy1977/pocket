#!/bin/bash

# Pocket Full Stack Setup Script
# This script configures both Pocket Backend (Java) and Pocket Web Backend (Rust)
# Prepares volumes, copies necessary files, and generates secure configuration
# Automatically detects and uses Podman or Docker

set -e  # Exit on any error

# Configuration
NETWORK=pocket-network
ENV_FILE=".env"
VOLUMES_DIR="docker-volumes"
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
    echo "║                    POCKET FULL STACK SETUP                   ║"
    echo "║                                                              ║"
    echo "║  🚀 Java Backend + Rust Web Backend + MariaDB                ║"
    echo "║  🔒 Secure configuration with auto-generated secrets         ║"
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

    if [ "$CONTAINER_RUNTIME" = "docker" ]; then
        CONTAINER_RUNTIME="sudo $CONTAINER_RUNTIME"
        COMPOSE_CMD="sudo $COMPOSE_CMD"
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
        "pocket-db-data"
        "pocket-logs"
        "pocket-web-logs"
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
    if [ -d "$VOLUMES_DIR/pocket-db-data" ]; then
        chmod 777 "$VOLUMES_DIR/pocket-db-data"  # MariaDB needs write access
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
        read -p "Admin username [admin@pocket.local]: " ADMIN_USER
        ADMIN_USER=${ADMIN_USER:-admin@pocket.local}
    fi
    
    if [ -z "$ADMIN_PASSWD" ]; then
        read -p "Generate secure admin password automatically? [Y/n]: " auto_admin_pass
        if [[ "$auto_admin_pass" =~ ^[Nn]$ ]]; then
            while true; do
                read -s -p "Enter admin password (exactly 32 characters): " ADMIN_PASSWD
                echo
                if [ ${#ADMIN_PASSWD} -eq 32 ]; then
                    break
                else
                    log_error "Admin password must be exactly 32 characters long (current: ${#ADMIN_PASSWD})"
                fi
            done
        else
            ADMIN_PASSWD=$(generate_password 32)
            log_success "Generated secure admin password (32 characters)"
        fi
    fi
    
    # Server configuration
    if [ -z "$SERVER_URL" ]; then
        read -p "Server URL [http://localhost:8081]: " SERVER_URL
        SERVER_URL=${SERVER_URL:-http://localhost:8081}
    fi
    
    # Extract port from SERVER_URL automatically
    if [ -z "$SERVER_PORT" ]; then
        EXTRACTED_PORT=$(echo "$SERVER_URL" | sed -n 's/.*:\([0-9]\+\).*/\1/p')
        if [ -n "$EXTRACTED_PORT" ]; then
            SERVER_PORT=$EXTRACTED_PORT
        else
            SERVER_PORT=8081
        fi
        log_success "Using port $SERVER_PORT from Server URL"
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
    
    # Pocket Host
    if [ -z "$POCKET_HOST" ]; then
        read -p "Bind address/hostname [0.0.0.0]: " POCKET_HOST
        POCKET_HOST=${POCKET_HOST:-0.0.0.0}
        
        # Convert localhost/127.0.0.1 to 0.0.0.0 for container binding
        if [ "$POCKET_HOST" = "localhost" ] || [ "$POCKET_HOST" = "127.0.0.1" ]; then
            POCKET_HOST="0.0.0.0"
            log_info "Converting to 0.0.0.0 for container binding"
        fi
    fi
    
    # Pocket Port
    if [ -z "$POCKET_PORT" ]; then
        while true; do
            read -p "Server port [8080]: " POCKET_PORT
            POCKET_PORT=${POCKET_PORT:-8080}
            if validate_port "$POCKET_PORT"; then
                break
            fi
        done
    fi
    
    # Backend URL (optional, overrides auto-built URL for frontend)
    if [ -z "$BACKEND_URL" ]; then
        read -p "Custom frontend URL (optional, leave empty for auto: http://POCKET_HOST:POCKET_PORT) []: " BACKEND_URL
        if [ -n "$BACKEND_URL" ]; then
            log_success "Using custom backend URL: $BACKEND_URL"
        else
            log_info "Will use auto-built URL for frontend configuration"
        fi
    fi
    
    if [ -z "$POCKET_MAX_THREADS" ]; then
        while true; do
            read -p "Max Threads [2]: " POCKET_MAX_THREADS
            POCKET_MAX_THREADS=${POCKET_MAX_THREADS:-2}
            if [[ "$POCKET_MAX_THREADS" =~ ^[0-9]+$ ]] && [ "$POCKET_MAX_THREADS" -gt 0 ]; then
                break
            else
                log_error "Max threads must be a positive number"
            fi
        done
    fi
    
    if [ -z "$POCKET_SESSION_EXPIRATION" ]; then
        while true; do
            read -p "Session Expiration (seconds) [300]: " POCKET_SESSION_EXPIRATION
            POCKET_SESSION_EXPIRATION=${POCKET_SESSION_EXPIRATION:-300}
            if [[ "$POCKET_SESSION_EXPIRATION" =~ ^[0-9]+$ ]] && [ "$POCKET_SESSION_EXPIRATION" -gt 0 ]; then
                break
            else
                log_error "Session expiration must be a positive number"
            fi
        done
    fi
    
    if [ -z "$CORS_ALLOWED_ORIGINS" ]; then
        read -p "Additional CORS origins (comma-separated) []: " CORS_ALLOWED_ORIGINS
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
POCKET_HOST=$POCKET_HOST
POCKET_PORT=$POCKET_PORT
BACKEND_URL=$BACKEND_URL
POCKET_MAX_THREADS=$POCKET_MAX_THREADS
POCKET_SESSION_EXPIRATION=$POCKET_SESSION_EXPIRATION
CORS_ALLOWED_ORIGINS=$CORS_ALLOWED_ORIGINS

# ===========================================
# GENERAL CONFIGURATION
# ===========================================
LOG_LEVEL=$LOG_LEVEL

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
    echo "   Host: $POCKET_HOST"
    echo "   Port: $POCKET_PORT"
    if [ -n "$BACKEND_URL" ]; then
        echo "   Frontend URL: $BACKEND_URL (custom)"
    else
        echo "   Frontend URL: http://$POCKET_HOST:$POCKET_PORT (auto)"
    fi
    echo "   Max Threads: $POCKET_MAX_THREADS"
    echo "   Session Expiration: $POCKET_SESSION_EXPIRATION seconds"
    if [ -n "$CORS_ALLOWED_ORIGINS" ]; then
        echo "   CORS Origins: $CORS_ALLOWED_ORIGINS"
    fi
    echo
    echo "⚙️  General:"
    echo "   Log Level: $LOG_LEVEL"
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
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\${BLUE}🚀 Starting Pocket Full Stack...\${NC}"

# Start services
echo -e "\${BLUE}Starting services...\${NC}"
$COMPOSE_CMD up -d pocket-db pocket-backend pocket-web-backend

echo -e "\${GREEN}✅ Services started successfully!\${NC}"
echo
echo "📋 Service URLs:"
echo "   Java Backend: \$SERVER_URL"
if [ -n "\$BACKEND_URL" ]; then
    echo "   Rust Web Backend: \$BACKEND_URL"
else
    echo "   Rust Web Backend: http://\$POCKET_HOST:\$POCKET_PORT"
fi
echo "   Database: localhost:3306"
echo
echo "🔧 Management commands:"
echo "   View logs: $COMPOSE_CMD logs -f"
echo "   Stop services: $COMPOSE_CMD down"
echo "   Restart: $COMPOSE_CMD restart"
echo
echo -e "\${BLUE}📦 Installing CLI tools...\${NC}"

# Create pocket-device wrapper
echo -e "\${YELLOW}Creating /usr/local/bin/pocket-device...\${NC}"
sudo tee /usr/local/bin/pocket-device > /dev/null << 'POCKET_DEVICE_EOF'
#!/bin/bash
sudo docker exec pocket-backend /var/www/pocket-device "\$@"
POCKET_DEVICE_EOF
sudo chmod +x /usr/local/bin/pocket-device
echo -e "\${GREEN}✅ pocket-device command installed\${NC}"

# Create pocket-user wrapper
echo -e "\${YELLOW}Creating /usr/local/bin/pocket-user...\${NC}"
sudo tee /usr/local/bin/pocket-user > /dev/null << 'POCKET_USER_EOF'
#!/bin/bash
sudo docker exec pocket-backend /var/www/pocket-user "\$@"
POCKET_USER_EOF
sudo chmod +x /usr/local/bin/pocket-user
echo -e "\${GREEN}✅ pocket-user command installed\${NC}"

echo
echo -e "\${GREEN}🎉 Setup complete!\${NC}"
echo
echo "💡 CLI tools available:"
echo "   pocket-device - Manage pocket devices"
echo "   pocket-user   - Manage pocket users"
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

# Function to create clean script
create_clean_script() {
    log_step "Creating clean script..."
    
    cat > "clean_pocket.sh" << EOF
#!/bin/bash

# Pocket Full Stack Clean Script
# This script removes all containers, volumes, and configuration files
# Generated by setup_environment.sh

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "\${RED}⚠️  WARNING: This will completely clean the Pocket environment!\${NC}"
echo -e "\${YELLOW}This action will:\${NC}"
echo "  - Stop all running containers"
echo "  - Remove all containers"
echo "  - Remove all volumes (DATABASE WILL BE DELETED!)"
echo "  - Remove configuration files (.env)"
echo "  - Remove volume directories ($VOLUMES_DIR/)"
echo

read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm

if [ "\$confirm" != "yes" ]; then
    echo -e "\${BLUE}Operation cancelled.\${NC}"
    exit 0
fi

echo
echo -e "\${BLUE}🧹 Starting cleanup process...\${NC}"
echo

# Stop and remove containers and volumes
echo -e "\${BLUE}Stopping and removing containers...\${NC}"
$COMPOSE_CMD down -v 2>/dev/null || true
echo -e "\${GREEN}✅ Containers and volumes removed\${NC}"

# Remove .env file
if [ -f ".env" ]; then
    echo -e "\${BLUE}Removing .env configuration...\${NC}"
    rm -f .env
    echo -e "\${GREEN}✅ .env file removed\${NC}"
fi

# Remove volume directories
if [ -d "$VOLUMES_DIR" ]; then
    echo -e "\${BLUE}Removing volume directories...\${NC}"
    rm -rf $VOLUMES_DIR
    echo -e "\${GREEN}✅ Volume directories removed\${NC}"
fi

# Remove CLI tools from /usr/local/bin
echo -e "\${BLUE}Removing CLI tools...\${NC}"
if [ -f "/usr/local/bin/pocket-device" ]; then
    sudo rm -f /usr/local/bin/pocket-device
    echo -e "\${GREEN}✅ Removed /usr/local/bin/pocket-device\${NC}"
fi
if [ -f "/usr/local/bin/pocket-user" ]; then
    sudo rm -f /usr/local/bin/pocket-user
    echo -e "\${GREEN}✅ Removed /usr/local/bin/pocket-user\${NC}"
fi

# Remove generated scripts (optional)
read -p "Remove generated scripts (start_pocket.sh, stop_pocket.sh, clean_pocket.sh, clean_images.sh)? [y/N]: " remove_scripts
if [[ "\$remove_scripts" =~ ^[Yy]\$ ]]; then
    rm -f start_pocket.sh stop_pocket.sh clean_pocket.sh clean_images.sh
    echo -e "\${GREEN}✅ Generated scripts removed\${NC}"
fi

echo
echo -e "\${GREEN}🎉 Cleanup completed successfully!\${NC}"
echo
echo "To set up the environment again, run:"
echo "  ./setup_environment.sh"
echo
EOF
    
    chmod +x "clean_pocket.sh"
    log_success "Created clean_pocket.sh"
}

# Function to create clean images script
create_clean_images_script() {
    log_step "Creating clean images script..."
    
    cat > "clean_images.sh" << 'EOF'
#!/bin/bash

###################################################################################
#
# Pocket - Clean Docker Images Script
# Copyright (C) 2018/2025 Antonio Salsi <passy.linux@zresa.it>
#
# This script removes Docker images created for the Pocket application
# Generated by setup_environment.sh
#
###################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

log_error() {
    echo -e "${RED}❌ ${NC}$1"
}

# Function to detect container runtime
detect_runtime() {
    if command -v docker &> /dev/null; then
        echo "docker"
    elif command -v podman &> /dev/null; then
        echo "podman"
    else
        echo ""
    fi
}

# Detect container runtime
CONTAINER_RUNTIME=$(detect_runtime)

if [ -z "$CONTAINER_RUNTIME" ]; then
    log_error "Neither Docker nor Podman is installed on this system"
    exit 1
fi

log_info "Using container runtime: $CONTAINER_RUNTIME"

# Banner
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        Pocket - Clean Docker Images Script               ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if containers are running
log_info "Checking for running Pocket containers..."
RUNNING_CONTAINERS=$(sudo $CONTAINER_RUNTIME ps -q -f name=pocket)

if [ -n "$RUNNING_CONTAINERS" ]; then
    log_warning "Pocket containers are currently running"
    echo ""
    echo -e "${YELLOW}The following containers will be stopped:${NC}"
    sudo $CONTAINER_RUNTIME ps -f name=pocket --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    read -p "Do you want to stop these containers? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Operation cancelled by user"
        exit 0
    fi
    
    log_info "Stopping containers..."
    if [ -f "compose.yaml" ]; then
        sudo $CONTAINER_RUNTIME compose down
    else
        sudo $CONTAINER_RUNTIME stop $RUNNING_CONTAINERS
        sudo $CONTAINER_RUNTIME rm $RUNNING_CONTAINERS
    fi
    log_success "Containers stopped and removed"
fi

# List Pocket images
log_info "Searching for Pocket images..."
echo ""

POCKET_IMAGES=$(sudo $CONTAINER_RUNTIME images --filter=reference='pocket-*' --format "{{.Repository}}:{{.Tag}}")

if [ -z "$POCKET_IMAGES" ]; then
    log_success "No Pocket images found"
    exit 0
fi

echo -e "${YELLOW}The following images will be removed:${NC}"
sudo $CONTAINER_RUNTIME images --filter=reference='pocket-*' --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
echo ""

# Confirm deletion
read -p "Are you sure you want to delete these images? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Operation cancelled by user"
    exit 0
fi

# Remove images
log_info "Removing Pocket images..."
echo ""

IMAGE_COUNT=0
for IMAGE in $POCKET_IMAGES; do
    log_info "Removing image: $IMAGE"
    if sudo $CONTAINER_RUNTIME rmi "$IMAGE" 2>/dev/null; then
        log_success "Removed: $IMAGE"
        ((IMAGE_COUNT++))
    else
        log_warning "Failed to remove: $IMAGE (may be in use)"
    fi
done

echo ""
if [ $IMAGE_COUNT -gt 0 ]; then
    log_success "Removed $IMAGE_COUNT Pocket image(s)"
else
    log_warning "No images were removed"
fi

# Optional: Clean up dangling images
echo ""
read -p "Do you want to remove dangling images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Removing dangling images..."
    DANGLING_COUNT=$(sudo $CONTAINER_RUNTIME images -f "dangling=true" -q | wc -l)
    
    if [ "$DANGLING_COUNT" -gt 0 ]; then
        sudo $CONTAINER_RUNTIME image prune -f
        log_success "Removed $DANGLING_COUNT dangling image(s)"
    else
        log_info "No dangling images found"
    fi
fi

# Optional: Clean up build cache
echo ""
read -p "Do you want to clean the build cache? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cleaning build cache..."
    sudo $CONTAINER_RUNTIME builder prune -f
    log_success "Build cache cleaned"
fi

echo ""
log_success "Image cleanup completed!"
echo ""

# Show remaining images
log_info "Remaining Pocket images:"
REMAINING=$(sudo $CONTAINER_RUNTIME images --filter=reference='pocket-*' --format "{{.Repository}}:{{.Tag}}")
if [ -z "$REMAINING" ]; then
    echo -e "${GREEN}  No Pocket images remaining${NC}"
else
    sudo $CONTAINER_RUNTIME images --filter=reference='pocket-*' --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
fi

echo ""
log_info "To rebuild images, run: ./start_pocket.sh"
echo ""
EOF
    
    chmod +x "clean_images.sh"
    log_success "Created clean_images.sh"
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
    echo "✅ Network configuration"
    echo "✅ Startup script (start_pocket.sh)"
    echo "✅ Stop script (stop_pocket.sh)"
    echo "✅ Clean script (clean_pocket.sh)"
    echo "✅ Clean images script (clean_images.sh)"
    echo
    echo "🚀 Next steps:"
    echo "============="
    echo "1. Build the Docker images:"
    echo "   ./build_docker.sh"
    echo
    echo "2. Start the services (will also install CLI tools):"
    echo "   ./start_pocket.sh"
    echo
    echo "3. Check service status:"
    echo "   $COMPOSE_CMD ps"
    echo
    echo "💡 CLI Tools:"
    echo "============"
    echo "After running ./start_pocket.sh, these commands will be available:"
    echo "   pocket-device - Manage pocket devices"
    echo "   pocket-user   - Manage pocket users"
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
            setup_directories
            copy_configuration_files
            create_startup_script
            create_stop_script
            create_clean_script
            create_clean_images_script
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
    create_clean_script
    create_clean_images_script
    
    # Display summary
    echo
    display_configuration_summary
    display_final_info
}

# Handle script interruption
trap 'log_error "Setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"