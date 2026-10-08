#!/usr/bin/env bash

# CONFIGURATION
WIDTH=640
HEIGHT=480
FPS=30
PORT=8080

# 1. Make sure lsof or fuser is installed
#    (sudo apt install lsof psmisc)
COMMAND_FOUND=false
if command -v fuser >/dev/null 2>&1; then
  COMMAND_FOUND=true
elif command -v lsof >/dev/null 2>&1; then
  COMMAND_FOUND=true
fi

if ! $COMMAND_FOUND; then
  echo "Please install lsof or psmisc (for fuser) and try again."
  exit 1
fi

# 2. Kill anything listening on TCP port $PORT
echo "Clearing port $PORT…"
if command -v fuser >/dev/null 2>&1; then
  # fuser -k will send SIGKILL to any process using that port
  sudo fuser -k ${PORT}/tcp
else
  # fallback to lsof + kill
  pids=$(lsof -ti tcp:$PORT)
  if [ -n "$pids" ]; then
    sudo kill -9 $pids
  fi
fi

# 3. Also kill any stray ffmpeg or libcamera-vid instances
pkill -9 -f "ffmpeg .*http://0\.0\.0\.0:${PORT}" 2>/dev/null || true
pkill -9 -f "libcamera-vid"                    2>/dev/null || true

# Give the kernel a moment to free the port
sleep 1

# 4. Start camera → HTTP MJPEG server
libcamera-vid -t 0 \
  --width $WIDTH --height $HEIGHT \
  --framerate $FPS \
  --codec mjpeg --inline -o - | \
ffmpeg -f mjpeg -i - \
  -listen 1 -c copy -f mjpeg \
  http://0.0.0.0:$PORT
