# Deploy Focus Backend to Raspberry Pi (Local Network)

Goal: run the NestJS backend on a Raspberry Pi and reach it on your local network at a known address, e.g. `http://focus.local:3000`.

This guide covers local HTTP access only. HTTPS and public DNS will be handled later.

---

## 1. SSH into the Pi

```bash
ssh focus@focus.local
```

If the hostname does not resolve, use the Pi's local IP address instead:

```bash
ssh focus@<pi-ip>
```

---

## 2. Install Docker on the Raspberry Pi

Once logged into the Pi:

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add the focus user to the docker group so sudo is not required
sudo usermod -aG docker focus

# Start Docker and enable it on boot
sudo systemctl enable docker
sudo systemctl start docker

# Verify installation
docker --version
docker compose version
```

Then **log out and SSH back in** so the group change takes effect:

```bash
exit
ssh focus@focus.local
```

---

## 3. Create the directory for secrets

On the Pi:

```bash
sudo mkdir -p /opt/focus/secrets
sudo chown -R focus:focus /opt/focus
```

---

## 4. Copy the Firebase service account key to the Pi

Download the production Firebase service account key (`focus-backend-prod.json`) from the Firebase console.

On your Mac, run:

```bash
scp /path/to/focus-backend-prod.json focus@focus.local:/opt/focus/secrets/
```

Then back on the Pi, verify the file is present:

```bash
ls -la /opt/focus/secrets/
```

---

## 5. Deploy the backend directly on the Pi

SSH into the Pi, then run the local deployment script from the `server` directory:

```bash
ssh focus@focus.local
cd /path/to/focus/server
npm run deploy:prod
```

This will:

1. Pull the latest changes from git.
2. Build the Docker image natively on the Pi.
3. Start the container on port `3000`.

Make sure the service account key and `.env.production` are already present on the Pi (see steps 3 and 4).

---

## 6. Verify the backend is running

On the Pi:

```bash
docker ps
docker logs focus-backend
```

From any device on your local network, open:

```text
http://focus.local:3000
```

Or using the Pi's IP address:

```text
http://<pi-ip>:3000
```

You should see the NestJS backend responding.

---

## 7. Give the Pi a stable local address (optional but recommended)

`focus.local` works via mDNS, but the underlying IP may still change after a reboot. To keep a known address, use one of these options.

### Option A — Static IP on the Pi

On the Pi:

```bash
sudo nano /etc/dhcpcd.conf
```

Add at the bottom, adjusted to your router and subnet:

```text
interface eth0
static ip_address=192.168.15.112/24
static routers=192.168.15.1
static domain_name_servers=192.168.15.1 8.8.8.8
```

Use `wlan0` instead of `eth0` if the Pi is connected via Wi-Fi.

Save, then reboot:

```bash
sudo reboot
```

### Option B — DHCP reservation on the router (preferred)

Log in to your router's admin panel and reserve `192.168.15.112` for the Pi's MAC address. This avoids IP conflicts and is easier to maintain than a static IP on the device.

---

## Next step

Once this is working locally over HTTP, the next phase is HTTPS and DNS resolution.
