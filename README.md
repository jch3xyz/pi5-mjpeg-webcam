# pi5-mjpeg-webcam

Turn a Raspberry Pi 5 and a Pi camera module into a network webcam you can open in a browser. A systemd service starts the camera at boot and serves it as an MJPEG stream on port 8080:

```
http://<hostname>.local:8080
```

It's one shell script and one service file, with no web server or framework to install.

## How it works

```
camera ──► libcamera-vid ──(MJPEG frames on stdout)──► ffmpeg ──► HTTP :8080
            640x480 @ 30 fps                            -listen 1, -c copy
```

- `libcamera-vid` reads the camera and encodes MJPEG.
- `ffmpeg` passes the frames through unchanged (`-c copy`, so no re-encoding) and serves them over HTTP with its built-in listener.
- `camera-stream.service` runs the script at boot and restarts it whenever it exits.

## Hardware

Tested on:

| | |
|---|---|
| Board | Raspberry Pi 5 Model B |
| Camera | Camera Module v2 (Sony IMX219) on the CSI connector |
| OS | Raspberry Pi OS Bookworm (Debian 12), 64-bit, 2025-05-13 image |
| Packages | rpicam-apps 1.7.0, ffmpeg 5.1.6 |

Any camera that `rpicam-hello --list-cameras` detects should work.

## Install

On the Pi:

```bash
git clone https://github.com/jch3xyz/pi5-mjpeg-webcam.git
cd pi5-mjpeg-webcam
./install.sh
```

The installer does the following:

1. installs `rpicam-apps`, `ffmpeg`, `psmisc` (for `fuser`) and `avahi-daemon` (so `<hostname>.local` resolves)
2. copies `start-camera-stream.sh` to `/usr/local/bin/`
3. installs `camera-stream.service` and enables it, so it starts now and at every boot

Check that the camera is detected first if anything looks wrong:

```bash
rpicam-hello --list-cameras
```

## Viewing the stream

- **Browser:** open `http://<hostname>.local:8080`, or `http://<pi-ip>:8080` (find the IP with `hostname -I` on the Pi).
- **VLC:** Media → Open Network Stream → `http://<hostname>.local:8080`
- **OBS:** add a Media Source, untick "Local File", and use the URL as the input.

## Configuration

Edit the variables at the top of `/usr/local/bin/start-camera-stream.sh`, then restart the service:

```bash
WIDTH=640
HEIGHT=480
FPS=30
PORT=8080
```

```bash
sudo systemctl restart camera-stream.service
```

If you change `PORT`, the URL changes to match.

## Limitations

These were tested on the hardware above:

- **One viewer at a time.** ffmpeg's `-listen 1` serves a single client. A second viewer can't connect while the first is watching.
- **Each disconnect restarts the pipeline.** When the viewer closes the stream, ffmpeg exits and systemd restarts the script. The stream is available again after about a second.
- **The script kills anything else on its port.** At every start it runs `fuser -k 8080/tcp`. If you also have `motion` installed, its web control uses port 8080 by default and will be killed every boot. The installer warns about this. Disable `motion` or move one of them to a different port.
- **No authentication.** Anyone who can reach the Pi on your network can view the stream. Don't expose port 8080 to the internet.
- **Runs as root**, so the script can free the port.

On newer Raspberry Pi OS releases the camera tools are called `rpicam-*`. If `libcamera-vid` isn't found, replace it with `rpicam-vid` in the script.

## Managing the service

```bash
systemctl status camera-stream.service       # is it running?
journalctl -u camera-stream.service -f       # live logs
sudo systemctl stop camera-stream.service    # stop until next boot
sudo systemctl disable --now camera-stream.service   # stop and don't start at boot
```

## Uninstall

```bash
sudo systemctl disable --now camera-stream.service
sudo rm /etc/systemd/system/camera-stream.service /usr/local/bin/start-camera-stream.sh
sudo systemctl daemon-reload
```

## License

MIT, see [LICENSE](LICENSE).
