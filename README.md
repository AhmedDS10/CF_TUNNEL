# Cloudflare Tunnel - Complete Usage Guide

## Prerequisites

Before running the script, ensure you have:

1. **A Cloudflare account** (free tier works)
2. **A domain added to Cloudflare** (with DNS managed by Cloudflare)
3. **Root/sudo access** on your Linux server
4. **Internet connection** on the server

## Step-by-Step Usage

### Step 1: Download and Prepare the Script

```bash
# Create the script file
nano cloudflared-setup.sh

# Paste the script content and save (Ctrl+X, Y, Enter)

# Make it executable
chmod +x cloudflared-setup.sh
```

### Step 2: Run the Script

```bash
sudo ./cloudflared-setup.sh
```

### Step 3: Choose Setup Option

You'll see a menu:
```
================================
Cloudflare Tunnel Setup Script
================================

1) Full setup (install, authenticate, create tunnel)
2) Install cloudflared only
3) Create new tunnel
4) List existing tunnels
5) Delete a tunnel
6) Exit
```

**For first-time setup, choose option 1**

### Step 4: Authentication

The script will open a browser window automatically. 

- Login to your Cloudflare account
- Select the domain you want to use
- Authorize cloudflared
- Return to terminal

**Note:** If you're on a headless server (no GUI), you'll see a URL. Copy it and open it on your local computer's browser.

### Step 5: Create Tunnel

```
Enter a name for your tunnel: my-home-server
```

Choose a descriptive name (e.g., `home-server`, `office-apps`, `dev-environment`)

### Step 6: Configure Tunnel Type

```
Select configuration type:
1) Single application (HTTP/HTTPS)
2) Multiple applications
3) Private network (full network access)

Enter choice [1-3]:
```

#### **Option 1: Single Application**
Best for exposing one internal service

**Example:**
```
Enter your domain: app.example.com
Enter internal service URL: http://localhost:3000
```

This will make your local app on port 3000 accessible at `https://app.example.com`

#### **Option 2: Multiple Applications**
Best for exposing several internal services

**Example:**
```
Enter hostname: app1.example.com
Enter service URL: http://localhost:3000

Enter hostname: app2.example.com
Enter service URL: http://192.168.1.10:8080

Enter hostname: done
```

Each service gets its own subdomain.

#### **Option 3: Private Network**
Best for full network access (requires WARP client on client devices)

**Example:**
```
Enter CIDR range: 192.168.1.0/24
```

This exposes your entire private network to authorized users with the Cloudflare WARP client.

## Real-World Examples

### Example 1: Expose a Home Server Web App

```bash
sudo ./cloudflared-setup.sh
# Choose: 1 (Full setup)
# Authenticate in browser
# Tunnel name: home-server
# Config type: 1 (Single application)
# Domain: homelab.yourdomain.com
# Service URL: http://localhost:8080
```

**Result:** Your app at `http://localhost:8080` is now accessible at `https://homelab.yourdomain.com`

### Example 2: Multiple Services (Dev Environment)

```bash
sudo ./cloudflared-setup.sh
# Choose: 1 (Full setup)
# Tunnel name: dev-env
# Config type: 2 (Multiple applications)

# Add services:
# api.yourdomain.com → http://localhost:3000
# admin.yourdomain.com → http://localhost:8080
# db-admin.yourdomain.com → http://localhost:5432
# Type 'done' when finished
```

**Result:** Three services accessible via different subdomains

### Example 3: Private Network Access

```bash
sudo ./cloudflared-setup.sh
# Choose: 1 (Full setup)
# Tunnel name: office-network
# Config type: 3 (Private network)
# CIDR: 10.0.0.0/24
```

**Result:** Entire office network accessible remotely via WARP client

## Managing Your Tunnel

### Check Tunnel Status

```bash
sudo systemctl status cloudflared
```

### View Logs

```bash
# Live logs
sudo journalctl -u cloudflared -f

# Last 50 lines
sudo journalctl -u cloudflared -n 50
```

### Restart Tunnel

```bash
sudo systemctl restart cloudflared
```

### Stop Tunnel

```bash
sudo systemctl stop cloudflared
```

### List All Tunnels

```bash
sudo ./cloudflared-setup.sh
# Choose: 4 (List existing tunnels)
```

Or directly:
```bash
cloudflared tunnel list
```

### Edit Configuration

```bash
sudo nano /etc/cloudflared/config.yml

# After editing, restart:
sudo systemctl restart cloudflared
```

### Delete a Tunnel

```bash
sudo ./cloudflared-setup.sh
# Choose: 5 (Delete a tunnel)
# Enter tunnel name or ID
```

## Common Use Cases

### 1. **Home Lab Access**
Expose your home server services without opening ports on your router
- No port forwarding needed
- No dynamic DNS required
- Secure HTTPS automatically

### 2. **Development Environment**
Share your local development server with team members or clients
```
dev.example.com → http://localhost:3000
```

### 3. **Self-Hosted Applications**
Expose applications like:
- Nextcloud (file storage)
- Plex/Jellyfin (media server)
- Home Assistant (smart home)
- GitLab (code repository)
- Portainer (Docker management)

### 4. **Remote Desktop Access**
Set up private network tunnel and use RDP/VNC through WARP client

### 5. **IoT Device Management**
Securely access IoT devices without exposing them to the internet

## Security Features

✅ **No inbound ports** - Only outbound connection needed
✅ **Automatic HTTPS** - TLS encryption by default
✅ **No firewall changes** - Works through NAT
✅ **DDoS protection** - Cloudflare's network protects you
✅ **Access control** - Can add Cloudflare Access policies

## Troubleshooting

### Tunnel won't start
```bash
# Check logs
sudo journalctl -u cloudflared -n 100

# Verify config file
sudo cloudflared tunnel info TUNNEL_NAME
```

### DNS not resolving
- Ensure domain is using Cloudflare nameservers
- Check DNS records in Cloudflare dashboard
- Wait a few minutes for DNS propagation

### Service unreachable
- Verify internal service is running: `curl http://localhost:PORT`
- Check firewall on local machine
- Ensure correct URL in config file

### Re-authenticate
```bash
cloudflared tunnel login
```

## Configuration File Example

Location: `/etc/cloudflared/config.yml`

```yaml
tunnel: abc123-def456-ghi789
credentials-file: /root/.cloudflared/abc123-def456-ghi789.json

ingress:
  - hostname: app1.example.com
    service: http://localhost:3000
  - hostname: app2.example.com
    service: http://192.168.1.10:8080
  - hostname: ssh.example.com
    service: ssh://localhost:22
  - service: http_status:404
```

## Advanced Features

### SSH Access Through Tunnel
```yaml
ingress:
  - hostname: ssh.example.com
    service: ssh://localhost:22
```

Then connect:
```bash
cloudflared access ssh --hostname ssh.example.com
```

### WebSocket Support
Automatically supported - no extra configuration needed

### Custom Origins
```yaml
ingress:
  - hostname: app.example.com
    service: https://192.168.1.10:8443
    originRequest:
      noTLSVerify: true
```

## Next Steps

After setup:
1. Test your tunnel: Visit your domain in a browser
2. Add Cloudflare Access for authentication (optional)
3. Monitor logs for any issues
4. Set up additional tunnels for other services

## Resources

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [WARP Client Download](https://1.1.1.1/)
- [Cloudflare Access Setup](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/)

---

**Remember:** Cloudflare Tunnels are free for up to 50 users. No credit card required!
