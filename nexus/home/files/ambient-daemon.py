#!/usr/bin/env python3
"""
Ambient light daemon — connects Hyperion (192.168.1.45:19444) to
screen content (video ambilight) and wallpaper colors (music breathing).
"""

import base64, json, math, os, re, socket, subprocess, sys, time

HYPERION_HOST = '192.168.1.45'
HYPERION_PORT = 19444
MAIN_MONITOR  = 'DP-3'
COLORS_FILE   = os.path.expanduser('~/.config/matugen/colors.sh')
PRIORITY      = 100
CAP_W, CAP_H  = 160, 90

VIDEO_CLASSES = {'vivaldi-stable', 'vivaldi', 'chromium', 'google-chrome-stable'}
VIDEO_TITLES  = ['aniworld', 'crunchyroll', 'youtube', 'youtu.be', 'music.apple.com']
JELLY_CLASSES = {'com.github.iwalton3.jellyfin-media-player', 'jellyfinmediaplayer'}

TMP_CAP = '/tmp/ambient_cap.png'
TMP_RGB = '/tmp/ambient_raw.rgb'


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


def capture_frame():
    try:
        r = subprocess.run(
            ['grim', '-o', MAIN_MONITOR, '-t', 'png', TMP_CAP],
            capture_output=True, timeout=2,
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


def detect_mode() -> str:
    try:
        r = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=2)
        for c in json.loads(r.stdout):
            if not c.get('mapped'):
                continue
            cls   = c.get('class', '').lower()
            title = c.get('title', '').lower()
            if cls in JELLY_CLASSES:
                return 'video'
            if cls in VIDEO_CLASSES and any(site in title for site in VIDEO_TITLES):
                return 'video'
    except Exception:
        pass

    try:
        r = subprocess.run(['playerctl', 'status'], capture_output=True, text=True, timeout=2)
        if r.stdout.strip() == 'Playing':
            return 'music'
    except Exception:
        pass

    return 'idle'


def main():
    hyp          = HyperionClient()
    colors       = parse_colors()
    prev         = colors.get('PRIMARY', (80, 120, 255))
    target       = prev
    colors_mtime = 0.0
    transition_t = 0.0
    TRANSITION_DUR = 2.0
    last_mode    = 'idle'
    t_start      = time.monotonic()

    while True:
        now = time.monotonic()

        # detect wallpaper color change
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

        mode = detect_mode()

        if mode == 'video':
            frame = capture_frame()
            if frame:
                hyp.image(frame)
            time.sleep(0.1)

        elif mode == 'music':
            elapsed    = now - t_start
            # breathing: 1.5 s cycle, 15 %–100 % brightness
            brightness = (math.sin(elapsed * math.pi * 2 / 1.5) + 1) / 2 * 0.85 + 0.15
            hyp.color(*(int(v * brightness) for v in active_color))
            time.sleep(0.05)

        else:
            if last_mode != 'idle':
                hyp.clear()
            time.sleep(0.5)

        last_mode = mode


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
