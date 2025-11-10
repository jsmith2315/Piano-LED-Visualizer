#!/usr/bin/env bash
# Piano-LED-Visualizer Autoinstall Script (Trixie ARM64, Pi Zero 2 W)
# Updated for /home/$(whoami) and optimized for Raspberry Pi OS Lite 64-bit

set -e

echo "🎹 Piano LED Visualizer - Installer for Raspberry Pi OS Trixie (64-bit)"
echo "-----------------------------------------------------------------------"

# Detect username and home directory dynamically
USER_NAME=$(whoami)
USER_HOME=$(eval echo "~$USER_NAME")
PROJECT_DIR="$USER_HOME/Piano-LED-Visualizer-master"

echo "👤 Running as user: $USER_NAME"
echo "📁 Project directory: $PROJECT_DIR"
sleep 2

# Step 1: Update system
echo "📦 Updating system..."
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt clean

# Step 2: Install all available system packages
echo "🧰 Installing required system packages..."
sudo apt install -y \
  python3 python3-venv python3-dev python3-pip \
  python3-numpy python3-rpi.gpio python3-spidev python3-rtmidi \
  python3-psutil python3-pil python3-flask python3-waitress \
  python3-websockets python3-werkzeug python3-mido python3-webcolors \
  libasound2-dev libportmidi-dev libffi-dev build-essential git

# Step 3: Create venv (with system packages)
echo "🐍 Setting up virtual environment with system packages..."
cd "$PROJECT_DIR"
if [ -d "venv" ]; then
  echo "⚙️ Virtual environment already exists, skipping creation."
else
  python3 -m venv venv --system-site-packages
fi

# Activate the environment
source venv/bin/activate

# Step 4: Install only what apt does NOT provide
echo "📦 Installing additional pip-only packages..."
pip install --no-cache-dir --upgrade pip setuptools wheel

# Install LED driver (the only missing dependency)
if ! python -c "import rpi_ws281x" &>/dev/null; then
  echo "Installing rpi-ws281x (LED control library)..."
  pip install --no-cache-dir rpi-ws281x==4.3.4 || {
    echo "⚠️  rpi-ws281x failed, installing Adafruit NeoPixel fallback..."
    pip install --no-cache-dir adafruit-circuitpython-neopixel
  }
else
  echo "✅ rpi-ws281x already installed."
fi

# Step 5: Enable required interfaces and overlays
echo "🧩 Configuring system interfaces..."
if ! grep -q "dtparam=spi=on" /boot/firmware/config.txt; then
  echo "dtparam=spi=on" | sudo tee -a /boot/firmware/config.txt
fi
if ! grep -q "dtparam=i2c_arm=on" /boot/firmware/config.txt; then
  echo "dtparam=i2c_arm=on" | sudo tee -a /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=ws2811" /boot/firmware/config.txt; then
  echo "dtoverlay=ws2811" | sudo tee -a /boot/firmware/config.txt
fi

echo "✅ Interfaces configured. You may need to reboot for changes to apply."

# Step 6: Fix any hardcoded /home/pi or /home/Piano paths
echo "🧹 Correcting hardcoded paths..."
grep -RIl "/home/pi" "$PROJECT_DIR" | xargs sudo sed -i "s|/home/pi|$USER_HOME|g" || true
grep -RIl "/home/Piano" "$PROJECT_DIR" | xargs sudo sed -i "s|/home/Piano|$PROJECT_DIR|g" || true
sudo chown -R "$USER_NAME":"$USER_NAME" "$PROJECT_DIR"

# Step 7: Offer to create systemd service
read -p "Would you like to install a systemd service to auto-start the visualizer on boot? [y/N]: " yn
if [[ $yn =~ ^[Yy]$ ]]; then
  SERVICE_PATH="/etc/systemd/system/pianoled.service"
  echo "🛠️ Creating systemd service at $SERVICE_PATH"
  sudo bash -c "cat > $SERVICE_PATH" <<EOF
[Unit]
Description=Piano LED Visualizer
After=network.target

[Service]
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/visualizer.py
WorkingDirectory=$PROJECT_DIR
Restart=always
User=$USER_NAME

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable pianoled
  echo "✅ Systemd service installed. It will start automatically after reboot."
fi

echo "-----------------------------------------------------------------------"
echo "🎉 Installation complete!"
echo "To start manually:"
echo "  source $PROJECT_DIR/venv/bin/activate"
echo "  sudo python3 $PROJECT_DIR/visualizer.py"
echo
echo "💡 Reboot your Pi if SPI/I²C or LED overlay was just enabled."
echo "-----------------------------------------------------------------------"
