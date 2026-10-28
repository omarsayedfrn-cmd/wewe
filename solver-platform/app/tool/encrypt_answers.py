#!/usr/bin/env python3
import json
import os
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding

ROOT = "/home/omsa/Projects/solver-project"
OUT_DIR = os.path.join(ROOT, "solver-platform/app/assets")
os.makedirs(OUT_DIR, exist_ok=True)
OUT_PATH = os.path.join(OUT_DIR, "answers.enc")

# Obfuscated Key: 32 bytes
KEY = b"S0lv3r_Pl4tf0rm_K3y_2026_Om4r!!!"
IV = b"Slvr_Init_Vect_!"

bundle = {}

sources = {
    "qureo": os.path.join(ROOT, "qureo-solver/answers.json"),
    "qureo_js_en": os.path.join(ROOT, "qureo-js-en-solver/answers.json"),
    "qureo2": os.path.join(ROOT, "qureo2-solver/answers.json"),
    "qureo2_en": os.path.join(ROOT, "qureo2-en-solver/answers.json"),
    "sprix": os.path.join(ROOT, "sprix-solver/answers.json"),
    "sprix_en": os.path.join(ROOT, "sprix-en-solver/answers.json"),
}

for engine, path in sources.items():
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            bundle[engine] = json.load(f)
        print(f"Loaded {engine} from {path}")
    else:
        print(f"Warning: {path} not found")

raw_json = json.dumps(bundle, separators=(',', ':')).encode('utf-8')
print(f"Raw bundle size: {len(raw_json)} bytes")

# Pad with PKCS7
padder = padding.PKCS7(128).padder()
padded_data = padder.update(raw_json) + padder.finalize()

cipher = Cipher(algorithms.AES(KEY), modes.CBC(IV))
encryptor = cipher.encryptor()
encrypted = encryptor.update(padded_data) + encryptor.finalize()

# Prepend IV (16 bytes)
final_payload = IV + encrypted

with open(OUT_PATH, "wb") as f:
    f.write(final_payload)

print(f"Encrypted bundle written to {OUT_PATH} (size: {len(final_payload)} bytes)")
