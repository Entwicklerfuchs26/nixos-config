#!/usr/bin/env bash
python3 -c "
import subprocess, json
r = subprocess.run(['curl', '-sf', 'http://localhost:7777/state'], capture_output=True, text=True)
d = json.loads(r.stdout.strip() or '{}')
print(json.dumps({'text': d.get('override') or 'auto', 'tooltip': 'LED Modus'}))
"
