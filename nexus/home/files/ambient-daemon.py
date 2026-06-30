#!/usr/bin/env python3
"""
Ambient light daemon — connects Hyperion (192.168.1.45:19444) to
screen content (video ambilight) and wallpaper colors (music breathing).
"""

import base64, json, math, os, re, socket, struct, subprocess, sys, threading, time

HYPERION_HOST     = '192.168.1.45'
HYPERION_PORT     = 19444
MAIN_MONITOR      = 'DP-3'
COLORS_FILE       = os.path.expanduser('~/.config/matugen/colors.sh')
PRIORITY          = 100
CAP_W, CAP_H      = 160, 90
DISABLED_LED_FROM = 250   # LEDs 250–299 sind unter dem Tisch

VIDEO_CLASSES  = {'vivaldi-stable', 'vivaldi', 'chromium', 'google-chrome-stable'}
VIDEO_TITLES   = ['aniworld', 'crunchyroll', 'youtube', 'youtu.be']
JELLY_CLASSES  = {'com.github.iwalton3.jellyfin-media-player', 'jellyfinmediaplayer'}
# Vivaldi PWA class substrings → video mode (z.B. vivaldi-www.crunchyroll.com__-Default)
VIDEO_CLS_SUB  = ['crunchyroll', 'aniworld', 'youtube', 'jellyfin']
# Vivaldi PWA class substrings → music mode
MUSIC_CLS_SUB  = ['music.apple.com', 'spotify']

TMP_CAP       = '/tmp/ambient_cap.png'
TMP_RGB       = '/tmp/ambient_raw.rgb'
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


def _capture_once() -> bytes | None:
    try:
        # WAYLAND_DISPLAY explizit setzen damit grim -o im systemd-Kontext funktioniert
        env = os.environ.copy()
        env.setdefault('WAYLAND_DISPLAY', 'wayland-1')
        r = subprocess.run(
            ['grim', '-o', MAIN_MONITOR, '-s', '0.0833', '-t', 'jpeg', TMP_CAP],
            capture_output=True, timeout=2, env=env,
        )
        if r.returncode != 0:
            return None
        r = subprocess.run(
            ['convert', TMP_CAP, '-resize', f'{CAP_W}x{CAP_H}!', '-depth', '8', f'rgb:{TMP_RGB}'],
            capture_output=True, timeout=2,
        )
        if r.returncode != 0:
            return None
        with open(TMP_RGB, 'rb') as f:
            data = f.read()
        return data if len(data) == CAP_W * CAP_H * 3 else None
    except Exception:
        return None


class ScreenCapture:
    """Nimmt Frames im Hintergrund auf — Hauptschleife holt immer den neuesten."""
    def __init__(self):
        self._frame  = None
        self._lock   = threading.Lock()
        self._stop   = False
        self._thread = None

    def start(self):
        self._stop = False
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def _loop(self):
        while not self._stop:
            frame = _capture_once()
            if frame:
                with self._lock:
                    self._frame = frame

    def get(self) -> bytes | None:
        with self._lock:
            return self._frame

    def stop(self):
        self._stop = True
        self._frame = None


def detect_mode() -> str:
    has_music = False
    try:
        r = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=2)
        for c in json.loads(r.stdout):
            if not c.get('mapped'):
                continue
            cls   = c.get('class', '').lower()
            title = c.get('title', '').lower()
            # Video hat Vorrang — sofort zurück
            if cls in JELLY_CLASSES:
                return 'video'
            if any(sub in cls for sub in VIDEO_CLS_SUB):
                return 'video'
            if cls in VIDEO_CLASSES and any(site in title for site in VIDEO_TITLES):
                return 'video'
            if any(sub in cls for sub in MUSIC_CLS_SUB):
                has_music = True
    except Exception:
        pass

    if has_music:
        return 'music'

    try:
        r = subprocess.run(['playerctl', 'status'], capture_output=True, text=True, timeout=2)
        if r.stdout.strip() == 'Playing':
            return 'music'
    except Exception:
        pass

    return 'idle'


def main():
    hyp          = HyperionClient()
    cava         = CavaReader()
    cap          = ScreenCapture()
    colors       = parse_colors()
    prev         = colors.get('PRIMARY', (80, 120, 255))
    target       = prev
    colors_mtime = 0.0
    transition_t = 0.0
    TRANSITION_DUR  = 2.0
    MODE_CHECK_INT  = 2.0
    last_mode       = 'idle'
    mode            = 'idle'
    last_mode_check = 0.0

    # Pixel-Maske für deaktivierte LEDs einmalig holen
    mask = fetch_disabled_mask(hyp)

    while True:
        now = time.monotonic()

        if now - last_mode_check >= MODE_CHECK_INT:
            mode            = detect_mode()
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
            time.sleep(0.1)

        elif mode == 'music':
            if last_mode != 'music':
                cap.stop()
                cava.start()
            br = cava.brightness
            r, g, b = (int(v * br) for v in active_color)
            hyp.image(solid_image(r, g, b, mask))
            time.sleep(0.033)

        else:
            if last_mode != 'idle':
                cap.stop()
                cava.stop()
                hyp.clear()
            time.sleep(0.5)

        last_mode = mode

        last_mode = mode


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
