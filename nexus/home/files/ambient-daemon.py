#!/usr/bin/env python3
"""
Ambient light daemon — connects Hyperion (192.168.1.45:19444) to
screen content (video ambilight) and wallpaper colors (music breathing).
"""

import base64, http.server, json, math, os, re, socket, socketserver, struct, subprocess, sys, threading, time

OPENRGB_RATE = 2.0   # OpenRGB update alle 2s (CLI-Aufruf im Hintergrund)

HYPERION_HOST     = '192.168.1.45'
HYPERION_PORT     = 19444
MAIN_MONITOR      = 'DP-3'
COLORS_FILE       = os.path.expanduser('~/.config/matugen/colors.sh')
PRIORITY          = 100
CAP_W, CAP_H      = 160, 90
DISABLED_LED_FROM = 250   # LEDs 250–299 sind unter dem Tisch

VIDEO_CLASSES  = {'vivaldi-stable', 'vivaldi', 'chromium', 'google-chrome-stable', 'steam'}
VIDEO_TITLES   = ['aniworld', 'crunchyroll', 'youtube', 'youtu.be']
JELLY_CLASSES  = {'com.github.iwalton3.jellyfin-media-player', 'jellyfinmediaplayer'}
# Vivaldi PWA class substrings → video mode (z.B. vivaldi-www.crunchyroll.com__-Default)
VIDEO_CLS_SUB  = ['crunchyroll', 'aniworld', 'youtube', 'jellyfin']
# Vivaldi PWA class substrings → music mode
MUSIC_CLS_SUB  = ['music.apple.com', 'spotify']

CAVA_PIPE     = '/tmp/ambient_cava_pipe'
CAVA_CONF     = '/tmp/ambient_cava.conf'

CAVA_CONF_TPL = """\
[general]
bars = 1
framerate = 30
sleep_timer = 0

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = {pipe}
data_format = binary
channels = mono
"""


CONTROL_PORT      = 7777
OVERRIDE_COOLDOWN = 5.0

_ctrl_lock        = threading.Lock()
_override_mode    = None
_override_monitor = None   # None → MAIN_MONITOR
_last_change      = 0.0


class _CtrlHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        if self.path == '/state':
            with _ctrl_lock:
                ov  = _override_mode
                mon = _override_monitor
            body = json.dumps({'override': ov, 'monitor': mon}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        global _override_mode, _override_monitor, _last_change
        parts = self.path.strip('/').split('/')
        # /mode/video/DP-1  oder  /mode/video  oder  /mode/music  etc.
        if parts[0] != 'mode':
            self.send_response(404); self.end_headers(); return
        if len(parts) == 3 and parts[1] == 'video':
            new_mode = 'video'
            new_mon  = parts[2]
        elif len(parts) == 2 and parts[1] in ('video', 'music', 'idle', 'auto'):
            new_mode = None if parts[1] == 'auto' else parts[1]
            new_mon  = None
        else:
            self.send_response(404); self.end_headers(); return
        now = time.monotonic()
        with _ctrl_lock:
            if now - _last_change < OVERRIDE_COOLDOWN:
                self.send_response(429); self.end_headers(); return
            _override_mode    = new_mode
            _override_monitor = new_mon if new_mode == 'video' else None
            _last_change      = now
        self.send_response(200)
        self.end_headers()


def _start_control_server():
    class _Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True
    srv = _Server(('0.0.0.0', CONTROL_PORT), _CtrlHandler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()


class CavaReader:
    def __init__(self):
        self.level   = 0.0
        self._peak   = 0.0   # schnell hoch, langsam runter
        self._avg    = 0.5   # langsamer Durchschnitt (passt sich an Lautstärke an)
        self._proc   = None
        self._thread = None
        self._stop   = False

    def start(self):
        if self._proc:
            return
        try:
            os.mkfifo(CAVA_PIPE)
        except FileExistsError:
            pass
        with open(CAVA_CONF, 'w') as f:
            f.write(CAVA_CONF_TPL.format(pipe=CAVA_PIPE))
        self._stop = False
        self._proc = subprocess.Popen(
            ['cava', '-p', CAVA_CONF],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def _loop(self):
        # Decay pro Frame bei 30fps: ~250ms Halbwertszeit
        DECAY     = 0.91
        AVG_ALPHA = 0.015  # langsamer Durchschnitt (~2s Anpassung)
        try:
            with open(CAVA_PIPE, 'rb') as f:
                while not self._stop:
                    data = f.read(2)
                    if len(data) == 2:
                        val = struct.unpack('<H', data)[0] / 65535.0
                        # Peak: sofort hoch, langsam runter
                        self._peak = val if val > self._peak else self._peak * DECAY
                        # Langzeit-Durchschnitt passt sich an Gesamtlautstärke an
                        self._avg  = self._avg * (1 - AVG_ALPHA) + val * AVG_ALPHA
                        # Helligkeit = wie viel der Peak über dem Durchschnitt liegt
                        floor = self._avg * 0.85
                        span  = max(0.001, 1.0 - floor)
                        self.level = max(0.0, min(1.0, (self._peak - floor) / span))
        except Exception:
            pass

    def stop(self):
        self._stop = True
        if self._proc:
            self._proc.terminate()
            self._proc = None
        try:
            os.unlink(CAVA_PIPE)
        except Exception:
            pass

    @property
    def brightness(self):
        # 0 %–100 %, beat-relativ (funktioniert auch bei komprimierter Musik)
        return self.level


class HyperionClient:
    def __init__(self):
        self._sock = None
        self._buf  = b''

    def _connect(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(2)
            s.connect((HYPERION_HOST, HYPERION_PORT))
            self._sock = s
            self._buf  = b''
        except Exception:
            self._sock = None

    def _read_response(self):
        while b'\n' not in self._buf:
            try:
                chunk = self._sock.recv(4096)
                if not chunk:
                    return None
                self._buf += chunk
            except Exception:
                return None
        idx = self._buf.index(b'\n')
        line, self._buf = self._buf[:idx], self._buf[idx + 1:]
        try:
            return json.loads(line.decode())
        except Exception:
            return None

    def send(self, cmd: dict):
        if not self._sock:
            self._connect()
        if not self._sock:
            return None
        try:
            self._sock.sendall((json.dumps(cmd) + '\n').encode())
            return self._read_response()
        except Exception:
            self._sock = None
            return None

    def clear(self):
        self.send({'command': 'clear', 'priority': PRIORITY})

    def color(self, r, g, b):
        self.send({
            'command': 'color',
            'color': [r, g, b],
            'priority': PRIORITY,
            'duration': -1,
            'origin': 'ambient-daemon',
        })

    def image(self, rgb_bytes: bytes):
        data = base64.b64encode(rgb_bytes).decode()
        self.send({
            'command': 'image',
            'imagewidth': CAP_W,
            'imageheight': CAP_H,
            'imagedata': data,
            'priority': PRIORITY,
            'duration': -1,
            'origin': 'ambient-daemon',
        })


class OpenRGBSetter:
    """Setzt alle RGB-Geräte per CLI (fire-and-forget, non-blocking)."""

    def __init__(self):
        self._proc   = None
        self._lock   = threading.Lock()

    def set_color(self, r, g, b):
        with self._lock:
            # Läuft noch ein alter Aufruf? Überspringen.
            if self._proc and self._proc.poll() is None:
                return
            color = f'{r:02X}{g:02X}{b:02X}'
            try:
                self._proc = subprocess.Popen(
                    ['openrgb', '-c', color],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                )
            except Exception:
                pass


def avg_frame_color(rgb_bytes):
    """Durchschnittsfarbe der Bildmitte (40–60 % vertikal, 20–80 % horizontal)."""
    r = g = b = n = 0
    x1, x2 = CAP_W // 5, CAP_W * 4 // 5
    y1, y2 = CAP_H * 2 // 5, CAP_H * 3 // 5
    for y in range(y1, y2):
        for x in range(x1, x2):
            i = (y * CAP_W + x) * 3
            r += rgb_bytes[i]; g += rgb_bytes[i+1]; b += rgb_bytes[i+2]; n += 1
    return (r // n, g // n, b // n) if n else (0, 0, 0)


def fetch_disabled_mask(hyp_client) -> bytearray:
    """Gibt eine Byte-Maske zurück: 1 = dieser Pixel gehört zu einem deaktivierten LED."""
    mask = bytearray(CAP_W * CAP_H)
    try:
        resp = hyp_client.send({'command': 'serverinfo', 'tan': 1})
        if not resp:
            return mask
        leds = resp.get('info', {}).get('leds', [])
        for led in leds[DISABLED_LED_FROM:]:
            x1 = int(led['hmin'] * CAP_W)
            x2 = max(x1 + 1, int(led['hmax'] * CAP_W))
            y1 = int(led['vmin'] * CAP_H)
            y2 = max(y1 + 1, int(led['vmax'] * CAP_H))
            for y in range(y1, min(y2, CAP_H)):
                for x in range(x1, min(x2, CAP_W)):
                    mask[y * CAP_W + x] = 1
    except Exception:
        pass
    return mask


def apply_mask(rgb_bytes: bytes, mask: bytearray) -> bytes:
    """Setzt Pixel auf schwarz wo mask==1."""
    data = bytearray(rgb_bytes)
    for i, m in enumerate(mask):
        if m:
            data[i * 3] = data[i * 3 + 1] = data[i * 3 + 2] = 0
    return bytes(data)


def solid_image(r: int, g: int, b: int, mask: bytearray) -> bytes:
    """Einfarbiges Bild mit deaktivierten LEDs auf schwarz."""
    data = bytearray(CAP_W * CAP_H * 3)
    for i in range(CAP_W * CAP_H):
        if not mask[i]:
            data[i * 3], data[i * 3 + 1], data[i * 3 + 2] = r, g, b
    return bytes(data)


def parse_colors() -> dict:
    result = {}
    try:
        with open(COLORS_FILE) as f:
            for line in f:
                m = re.match(r'export MATUGEN_(\w+)="(#[0-9a-fA-F]{6})"', line)
                if m:
                    h = m.group(2).lstrip('#')
                    result[m.group(1)] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
    except Exception:
        pass
    return result


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _capture_once(region=None, monitor=None):
    try:
        env = os.environ.copy()
        env.setdefault('WAYLAND_DISPLAY', 'wayland-1')
        if region:
            grim_cmd = ['grim', '-g', region, '-t', 'jpeg', '-']
        else:
            grim_cmd = ['grim', '-o', monitor or MAIN_MONITOR, '-s', '0.0833', '-t', 'jpeg', '-']
        grim = subprocess.Popen(
            grim_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env,
        )
        conv = subprocess.Popen(
            ['magick', '-', '-resize', f'{CAP_W}x{CAP_H}!', '-flip', '-depth', '8', 'rgb:-'],
            stdin=grim.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        grim.stdout.close()
        data, _ = conv.communicate(timeout=3)
        grim.wait(timeout=1)
        return data if len(data) == CAP_W * CAP_H * 3 else None
    except Exception:
        return None


class ScreenCapture:
    """Nimmt Frames im Hintergrund auf — Hauptschleife holt immer den neuesten."""
    def __init__(self):
        self._frame   = None
        self._region  = None   # 'x,y WxH' für grim -g, hat Vorrang
        self._monitor = None   # Monitorname für grim -o, None → MAIN_MONITOR
        self._lock    = threading.Lock()
        self._stop    = False
        self._thread  = None

    def set_region(self, region):
        with self._lock:
            self._region  = region
            self._monitor = None

    def set_monitor(self, monitor):
        """Capture ganzen Monitor (kein Fenster-Crop)."""
        with self._lock:
            self._region  = None
            self._monitor = monitor

    def start(self):
        self._stop = False
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def _loop(self):
        while not self._stop:
            with self._lock:
                region  = self._region
                monitor = self._monitor
            frame = _capture_once(region, monitor)
            if frame:
                with self._lock:
                    self._frame = frame

    def get(self):
        with self._lock:
            return self._frame

    def stop(self):
        self._stop = True
        self._frame = None


def detect_mode():
    """Returns (mode, region_str_or_None) — region ist 'x,y WxH' für grim -g."""
    has_music = False
    try:
        r = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=2)
        for c in json.loads(r.stdout):
            if not c.get('mapped'):
                continue
            cls   = c.get('class', '').lower()
            title = c.get('title', '').lower()
            at, sz = c.get('at', [0, 0]), c.get('size', [1920, 1080])
            region = f'{at[0]},{at[1]} {sz[0]}x{sz[1]}'
            if cls in JELLY_CLASSES:
                return 'video', region
            if cls.startswith('steam_app_'):
                return 'video', region
            if any(sub in cls for sub in VIDEO_CLS_SUB):
                return 'video', region
            if cls in VIDEO_CLASSES and any(site in title for site in VIDEO_TITLES):
                return 'video', region
            if any(sub in cls for sub in MUSIC_CLS_SUB):
                has_music = True
    except Exception:
        pass

    if has_music:
        return 'music', None

    try:
        r = subprocess.run(['playerctl', 'status'], capture_output=True, text=True, timeout=2)
        if r.stdout.strip() == 'Playing':
            return 'music', None
    except Exception:
        pass

    return 'idle', None


def main():
    hyp          = HyperionClient()
    cava         = CavaReader()
    cap          = ScreenCapture()
    orgb         = OpenRGBSetter()
    colors       = parse_colors()
    prev         = colors.get('PRIMARY', (80, 120, 255))
    target       = prev
    colors_mtime = 0.0
    transition_t = 0.0
    TRANSITION_DUR  = 2.0
    MODE_CHECK_INT  = 2.0
    last_mode       = 'idle'
    mode            = 'idle'
    region          = None
    last_mode_check = 0.0
    last_orgb_upd   = 0.0

    # Pixel-Maske für deaktivierte LEDs einmalig holen
    mask = fetch_disabled_mask(hyp)
    hyp.clear()  # alten eingefrorenen Frame aus vorheriger Session entfernen
    _start_control_server()

    while True:
        now = time.monotonic()

        if now - last_mode_check >= MODE_CHECK_INT:
            with _ctrl_lock:
                ov     = _override_mode
                ov_mon = _override_monitor
            if ov:
                mode = ov
                if ov == 'video':
                    cap.set_monitor(ov_mon)   # None → MAIN_MONITOR
                else:
                    region = None
            else:
                mode, region = detect_mode()
                if region:
                    cap.set_region(region)
            last_mode_check = now

        try:
            mtime = os.path.getmtime(COLORS_FILE)
            if mtime != colors_mtime:
                colors_mtime = mtime
                new_primary = parse_colors().get('PRIMARY', target)
                if new_primary != target:
                    prev         = target
                    target       = new_primary
                    transition_t = now
        except Exception:
            pass

        t_blend      = min(1.0, (now - transition_t) / TRANSITION_DUR) if transition_t else 1.0
        active_color = lerp(prev, target, t_blend)

        if mode == 'video':
            if last_mode != 'video':
                if last_mode == 'music':
                    cava.stop()
                cap.start()
            frame = cap.get()
            if frame:
                hyp.image(apply_mask(frame, mask))
                if now - last_orgb_upd >= OPENRGB_RATE:
                    or_r, or_g, or_b = avg_frame_color(frame)
                    orgb.set_color(or_r, or_g, or_b)
                    last_orgb_upd = now
            time.sleep(0.05)

        elif mode == 'music':
            if last_mode != 'music':
                cap.stop()
                cava.start()
            br = cava.brightness
            r, g, b = (int(v * br) for v in active_color)
            hyp.image(solid_image(r, g, b, mask))
            if now - last_orgb_upd >= OPENRGB_RATE:
                orgb.set_color(r, g, b)
                last_orgb_upd = now
            time.sleep(0.033)

        else:
            if last_mode != 'idle':
                cap.stop()
                cava.stop()
                orgb.set_color(0, 0, 0)
            r, g, b = (int(v * 0.35) for v in active_color)
            hyp.image(solid_image(r, g, b, mask))
            time.sleep(0.5)

        last_mode = mode


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
