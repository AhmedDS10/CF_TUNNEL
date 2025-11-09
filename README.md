I'll create a comprehensive bash script for setting up a Cloudflare Tunnel with cloudflared. This script will help you create secure outbound-only connections to your internal applications.I've created a comprehensive bash script for setting up Cloudflare Tunnels with cloudflared. Here's what it includes:

## Features:

1. **Automatic Installation** - Detects OS (Ubuntu/Debian/CentOS/RHEL/Fedora) and installs cloudflared
2. **Three Configuration Types:**
   - Single application tunnel (one domain → one service)
   - Multiple applications (multiple domains → multiple services)
   - Private network tunnel (full network access via WARP)

3. **Full Automation:**
   - Authentication with Cloudflare
   - Tunnel creation
   - DNS routing
   - System service installation
   - Configuration file generation

4. **Management Features:**
   - List existing tunnels
   - Delete tunnels
   - Test tunnel connectivity

## Usage:

```bash
# Save the script
chmod +x cloudflared-setup.sh

# Run with sudo
sudo ./cloudflared-setup.sh
```

The script will guide you through:
1. Installing cloudflared
2. Authenticating with your Cloudflare account
3. Creating and naming your tunnel
4. Configuring routes (applications or networks)
5. Setting up as a system service

## What it does:

- **Outbound-only connections**: No inbound firewall rules needed
- **Secure tunneling**: All traffic encrypted through Cloudflare's network
- **Automatic DNS**: Routes domains through Cloudflare DNS
- **System service**: Runs automatically on boot with systemd

The tunnel will run in the background and automatically reconnect if the connection drops!
