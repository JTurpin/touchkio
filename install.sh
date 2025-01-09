#!/usr/bin/env bash

# Determine system architecture
echo -e "Determining system architecture..."

case "$(uname -m)" in
    aarch64)
        ARCH="arm64"
        ;;
    x86_64)
        ARCH="amd64"
        ;;
    *)
        echo "System architecture $(uname -m) not supported."
        exit 1
        ;;
esac
echo "System architecture $ARCH is supported."

# Download the latest .deb package
echo -e "\nDownloading the latest release..."

DEB_URL=$(wget -qO- https://api.github.com/repos/leukipp/touchkio/releases/latest | \
grep -o "\"browser_download_url\": \"[^\"]*_${ARCH}\.deb\"" | \
sed 's/"browser_download_url": "//;s/"//g')
DEB_PATH="/tmp/$(basename "$DEB_URL")"

if [ -z "$DEB_URL" ]; then
    echo "Download url for .deb file not found."
    exit 1
fi

if ! wget --show-progress -q -O "$DEB_PATH" "$DEB_URL"; then
    echo "Failed to download the .deb file."
    exit 1
fi

# Install the latest .deb package
echo -e "\nInstalling the latest release..."

if ! command -v dpkg &> /dev/null; then
    echo "Package manager dpkg was not found."
    exit 1
fi

if ! sudo dpkg -i "$DEB_PATH"; then
    echo "Installation of .deb file failed."
    exit 1
fi

# Create the systemd user service
echo -e "\nCreating systemd user service..."

SERVICE_FILE="$HOME/.config/systemd/user/touchkio.service"
mkdir -p "$(dirname "$SERVICE_FILE")" || { echo "Failed to create directory for $SERVICE_FILE"; exit 1; }

bash -c "cat << EOF > \"$SERVICE_FILE\"
[Unit]
Description=TouchKio
After=graphical.target

[Service]
ExecStart=/usr/bin/touchkio
Restart=on-failure
RestartSec=5s 

[Install]
WantedBy=default.target
EOF"

systemctl --user enable "$(basename "$SERVICE_FILE")" || { echo "Failed to enable service $SERVICE_FILE"; exit 1; }
echo "Service $SERVICE_FILE enabled"

# Export display variables
echo -e "\nExporting display variables..."

if [ -z "$DISPLAY" ]; then
    export DISPLAY=":0"
    echo "DISPLAY was not set, defaulting to \"$DISPLAY\""
else
    echo "DISPLAY is set to \"$DISPLAY\""
fi
if [ -z "$WAYLAND_DISPLAY" ]; then
    export WAYLAND_DISPLAY="wayland-0"
    echo "WAYLAND_DISPLAY was not set, defaulting to \"$WAYLAND_DISPLAY\""
else
    echo "WAYLAND_DISPLAY is set to \"$WAYLAND_DISPLAY\""
fi

# Start the setup mode
echo ""
read -p "Start touchkio setup? (Y/n) " answer
if [[ ${answer:-y} == [Yy]* ]]; then
    echo "/usr/bin/touchkio --setup"
    /usr/bin/touchkio --setup
fi
