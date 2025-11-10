#!/usr/bin/env bash
# Piano-LED-Visualizer — Clean Installer for Raspberry Pi OS Lite (Trixie 64-bit)
# Safe for SSH connections (hotspot auto-disable)
# Tested on Raspberry Pi Zero 2 W

set -e

echo "🎹 Piano-LED-Visualizer — Automated Installer (Trixie 64-bit, Safe Mode)"
echo "-------------------------------------------------------------------------------"

# --- Detect user and paths ------------------------------------------------------
USER_NAME=$(whoami)
USER_HOME=$(eval echo "~$USER_NAME")
PROJECT_DIR="$USER_HOME/Piano-LED-Visualizer"

echo "👤 Installing for user: $USER_NAME"
echo "📂 Project directory:   $PROJECT_DIR"
sleep 2

# --- 1️⃣ Update system ---------------------------------------------------------
echo "📦 Updating system packages..."
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt clean

# --- 2️⃣ Install dependencies --------------------------------------------------
echo "🧰 Installing required dependencies..."
sudo apt install -y \
  python3 python3-venv python3-dev python3-pip python3-numpy \
  python3-rpi.gpio python3-spidev python3-rtmidi python3-psutil \
  python3-pil python3-flask python3-waitress python3-websockets \
  python3-werkzeug python3-mido python3-webcolors \
  libasound2-dev libportmidi-dev libffi-dev build-essential git \
  fonts-freefont-ttf avahi-daemon

# --- 3️⃣ Project directory -----------------------------------------------------
if [ ! -d "$PROJECT_DIR" ]; then
  echo "📁 Creating $PROJECT_DIR ..."
  mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# --- 4️⃣ Python venv using system packages ------------------------------------
echo "🐍 Creating Python virtual environment..."
if [ ! -d "venv" ]; then
  python3 -m venv venv --system-site-packages
fi
source venv/bin/activate

# --- 5️⃣ Pip-only installs -----------------------------------------------------
echo "📦 Installing pip-only dependencies..."
pip install --no-cache-dir --upgrade pip setuptools wheel
if ! python -c "import rpi_ws281x" &>/dev/null; then
  echo "Installing rpi-ws281x (LED driver)..."
  pip install --no-cache-dir rpi-ws281x==4.3.4 || \
  pip install --no-cache-dir adafruit-circuitpython-neopixel
fi

# --- 6️⃣ Fix hardcoded paths ---------------------------------------------------
echo "🧹 Fixing hardcoded paths..."
grep -RIl "/home/pi" "$PROJECT_DIR" | xargs sed -i "s|/home/pi|$USER_HOME|g" || true
grep -RIl "Piano-LED-Visualizer-LED-Visualizer" "$PROJECT_DIR" | \
  xargs sed -i "s|Piano-LED-Visualizer-LED-Visualizer|Piano-LED-Visualizer|g" || true
sudo chown -R "$USER_NAME:$USER_NAME" "$PROJECT_DIR"

# --- 7️⃣ Disable hotspot auto-enable ------------------------------------------
# This prevents the Wi-Fi interface from dropping when the visualizer starts.
echo "🚫 Disabling hotspot auto-activation..."
HOTSPOT_FILE="$PROJECT_DIR/lib/platform.py"
if grep -q "manage_hotspot" "$HOTSPOT_FILE"; then
  sudo sed -i 's/self\.manage_hotspot/# self.manage_hotspot/' "$HOTSPOT_FILE"
  sudo sed -i 's/platform.manage_hotspot/# platform.manage_hotspot/' "$HOTSPOT_FILE"
  sudo sed -i 's/check_and_enable_hotspot/# check_and_enable_hotspot/' "$HOTSPOT_FILE"
  echo "✅ Hotspot auto-activation disabled."
else
  echo "ℹ️  Hotspot code not found (already disabled)."
fi

# --- 8️⃣ Enable SPI/I²C interfaces --------------------------------------------
echo "🧩 Enabling SPI and I²C..."
sudo grep -qxF "dtparam=spi=on" /boot/firmware/config.txt || echo "dtparam=spi=on" | sudo tee -a /boot/firmware/config.txt
sudo grep -qxF "dtparam=i2c_arm=on" /boot/firmware/config.txt || echo "dtparam=i2c_arm=on" | sudo tee -a /boot/firmware/config.txt
sudo grep -qxF "dtoverlay=ws2811" /boot/firmware/config.txt || echo "dtoverlay=ws2811" | sudo tee -a /boot/firmware/config.txt

# --- 9️⃣ Create systemd service ------------------------------------------------
SERVICE_FILE="/etc/systemd/system/pianoled.service"
echo "⚙️ Creating systemd service..."

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Piano LED Visualizer
After=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'source $PROJECT_DIR/venv/bin/activate && exec python3 $PROJECT_DIR/visualizer.py'
Restart=always
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pianoled

# --- 🔟 Final output -----------------------------------------------------------
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "-------------------------------------------------------------------------------"
echo "✅ Installation complete!"
echo "📂 Project directory: $PROJECT_DIR"
echo "🌐 Web interface: http://$IP_ADDR:8765"
echo "💡 SPI/I²C enabled; reboot recommended if this is your first install."
echo
echo "Manage service:"
echo "  sudo systemctl start pianoled"
echo "  sudo systemctl stop pianoled"
echo "  sudo systemctl status pianoled"
echo
echo "To start manually:"
echo "  source $PROJECT_DIR/venv/bin/activate"
echo "  python3 $PROJECT_DIR/visualizer.py"
echo "-------------------------------------------------------------------------------"
