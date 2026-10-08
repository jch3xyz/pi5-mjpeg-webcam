#!/usr/bin/env bash
# Install the Pi camera MJPEG stream as a boot-time service.
# Run on the Raspberry Pi from a clone of this repo:  ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "Installing packages…"
sudo apt update
# rpicam-apps provides libcamera-vid, ffmpeg serves the stream over HTTP,
# psmisc provides fuser (used to clear the port), avahi-daemon makes <hostname>.local work.
sudo apt install -y rpicam-apps ffmpeg psmisc avahi-daemon

echo "Installing stream script and service…"
sudo install -m 755 start-camera-stream.sh /usr/local/bin/start-camera-stream.sh
sudo install -m 644 camera-stream.service /etc/systemd/system/camera-stream.service

# The stream script frees port 8080 at every start, which kills anything else using it.
# motion's web control defaults to 8080, so warn rather than let it be killed every boot.
if systemctl is-enabled --quiet motion 2>/dev/null; then
  echo "Note: motion is enabled and uses port 8080; the stream will kill it at every start."
  echo "      Disable it with: sudo systemctl disable --now motion"
fi

sudo systemctl daemon-reload
sudo systemctl enable --now camera-stream.service

echo
echo "Done. Open http://$(hostname).local:8080 (or http://<pi-ip>:8080)."
