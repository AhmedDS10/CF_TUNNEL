#!/bin/bash

# Cloudflare Tunnel Setup Script
# This script automates the installation and configuration of cloudflared
# for creating secure tunnels to internal applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    print_info "Detected OS: $OS $VER"
}

# Install cloudflared
install_cloudflared() {
    print_info "Installing cloudflared..."
    
    case $OS in
        ubuntu|debian)
            # Add cloudflare gpg key
            mkdir -p --mode=0755 /usr/share/keyrings
            curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
            
            # Add repository
            echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list
            
            # Update and install
            apt-get update && apt-get install -y cloudflared
            ;;
        centos|rhel|fedora)
            # Add repository
            cat <<EOF > /etc/yum.repos.d/cloudflared.repo
[cloudflared]
name=cloudflared
baseurl=https://pkg.cloudflare.com/cloudflared/rpm
enabled=1
gpgcheck=1
gpgkey=https://pkg.cloudflare.com/cloudflare-main.gpg
EOF
            yum install -y cloudflared
            ;;
        *)
            print_error "Unsupported operating system: $OS"
            print_info "Please install cloudflared manually from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
            exit 1
            ;;
    esac
    
    print_success "cloudflared installed successfully"
}

# Check if cloudflared is installed
check_cloudflared() {
    if command -v cloudflared &> /dev/null; then
        print_success "cloudflared is already installed ($(cloudflared --version))"
        return 0
    else
        return 1
    fi
}

# Authenticate with Cloudflare
authenticate_cloudflare() {
    print_info "Authenticating with Cloudflare..."
    print_info "This will open a browser window. Please login to your Cloudflare account."
    cloudflared tunnel login
    print_success "Authentication successful"
}

# Create tunnel
create_tunnel() {
    read -p "Enter a name for your tunnel: " TUNNEL_NAME
    
    if [[ -z "$TUNNEL_NAME" ]]; then
        print_error "Tunnel name cannot be empty"
        exit 1
    fi
    
    print_info "Creating tunnel: $TUNNEL_NAME"
    cloudflared tunnel create "$TUNNEL_NAME"
    
    # Get tunnel ID
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    print_success "Tunnel created with ID: $TUNNEL_ID"
    
    echo "$TUNNEL_ID" > /tmp/tunnel_id.txt
}

# Configure tunnel
configure_tunnel() {
    TUNNEL_ID=$(cat /tmp/tunnel_id.txt)
    
    print_info "Configuring tunnel routes..."
    echo ""
    echo "Select configuration type:"
    echo "1) Single application (HTTP/HTTPS)"
    echo "2) Multiple applications"
    echo "3) Private network (full network access)"
    read -p "Enter choice [1-3]: " CONFIG_TYPE
    
    mkdir -p /etc/cloudflared
    
    case $CONFIG_TYPE in
        1)
            configure_single_app "$TUNNEL_ID"
            ;;
        2)
            configure_multiple_apps "$TUNNEL_ID"
            ;;
        3)
            configure_private_network "$TUNNEL_ID"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Configure single application
configure_single_app() {
    local tunnel_id=$1
    
    read -p "Enter your domain (e.g., app.example.com): " DOMAIN
    read -p "Enter internal service URL (e.g., http://localhost:8080): " SERVICE_URL
    
    cat > /etc/cloudflared/config.yml <<EOF
tunnel: $tunnel_id
credentials-file: /root/.cloudflared/$tunnel_id.json

ingress:
  - hostname: $DOMAIN
    service: $SERVICE_URL
  - service: http_status:404
EOF
    
    print_success "Configuration file created at /etc/cloudflared/config.yml"
    
    # Route DNS
    print_info "Routing DNS..."
    cloudflared tunnel route dns "$tunnel_id" "$DOMAIN"
    print_success "DNS route created for $DOMAIN"
}

# Configure multiple applications
configure_multiple_apps() {
    local tunnel_id=$1
    
    cat > /etc/cloudflared/config.yml <<EOF
tunnel: $tunnel_id
credentials-file: /root/.cloudflared/$tunnel_id.json

ingress:
EOF
    
    while true; do
        read -p "Enter hostname (e.g., app1.example.com) or 'done' to finish: " HOSTNAME
        if [[ "$HOSTNAME" == "done" ]]; then
            break
        fi
        
        read -p "Enter service URL for $HOSTNAME (e.g., http://localhost:8080): " SERVICE_URL
        
        cat >> /etc/cloudflared/config.yml <<EOF
  - hostname: $HOSTNAME
    service: $SERVICE_URL
EOF
        
        # Route DNS
        cloudflared tunnel route dns "$tunnel_id" "$HOSTNAME"
        print_success "Added route for $HOSTNAME"
    done
    
    # Add catch-all
    cat >> /etc/cloudflared/config.yml <<EOF
  - service: http_status:404
EOF
    
    print_success "Configuration file created at /etc/cloudflared/config.yml"
}

# Configure private network
configure_private_network() {
    local tunnel_id=$1
    
    read -p "Enter CIDR range for private network (e.g., 10.0.0.0/8): " CIDR
    
    cat > /etc/cloudflared/config.yml <<EOF
tunnel: $tunnel_id
credentials-file: /root/.cloudflared/$tunnel_id.json

warp-routing:
  enabled: true
EOF
    
    print_success "Configuration file created at /etc/cloudflared/config.yml"
    
    # Route IP
    print_info "Routing private network..."
    cloudflared tunnel route ip add "$CIDR" "$tunnel_id"
    print_success "Private network route created for $CIDR"
}

# Install as system service
install_service() {
    print_info "Installing cloudflared as a system service..."
    
    cloudflared service install
    systemctl enable cloudflared
    systemctl start cloudflared
    
    print_success "Service installed and started"
    print_info "Service status:"
    systemctl status cloudflared --no-pager
}

# Test tunnel
test_tunnel() {
    print_info "Testing tunnel configuration..."
    cloudflared tunnel info "$(cat /tmp/tunnel_id.txt)"
}

# Main menu
main_menu() {
    echo ""
    echo "================================"
    echo "Cloudflare Tunnel Setup Script"
    echo "================================"
    echo ""
    echo "1) Full setup (install, authenticate, create tunnel)"
    echo "2) Install cloudflared only"
    echo "3) Create new tunnel"
    echo "4) List existing tunnels"
    echo "5) Delete a tunnel"
    echo "6) Exit"
    echo ""
    read -p "Enter choice [1-6]: " CHOICE
    
    case $CHOICE in
        1)
            full_setup
            ;;
        2)
            if ! check_cloudflared; then
                install_cloudflared
            fi
            ;;
        3)
            if ! check_cloudflared; then
                print_error "cloudflared is not installed. Please install it first."
                exit 1
            fi
            authenticate_cloudflare
            create_tunnel
            configure_tunnel
            install_service
            test_tunnel
            ;;
        4)
            cloudflared tunnel list
            ;;
        5)
            read -p "Enter tunnel name or ID to delete: " TUNNEL_TO_DELETE
            cloudflared tunnel delete "$TUNNEL_TO_DELETE"
            print_success "Tunnel deleted"
            ;;
        6)
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Full setup
full_setup() {
    check_root
    detect_os
    
    if ! check_cloudflared; then
        install_cloudflared
    fi
    
    authenticate_cloudflare
    create_tunnel
    configure_tunnel
    install_service
    test_tunnel
    
    echo ""
    print_success "Tunnel setup complete!"
    print_info "Your tunnel is now running as a system service"
    print_info "Check status with: systemctl status cloudflared"
    print_info "View logs with: journalctl -u cloudflared -f"
}

# Start script
main_menu
