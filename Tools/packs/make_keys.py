#!/usr/bin/env python3
"""Makes the Ed25519 key pair that signs manifest.json.

  python3 Tools/packs/make_keys.py

Prints PACKS_SIGNING_KEY (the private seed: keep it as a CI/Worker secret, never commit it) and the public key, which goes into
`PackConfig.publicKey` in Witness/Services/PackStore.swift. Run once; changing the key means shipping an app update.
"""
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

key = Ed25519PrivateKey.generate()
seed = key.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption())
public = key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
print("PACKS_SIGNING_KEY=" + base64.b64encode(seed).decode())
print("PackConfig.publicKey = \"" + base64.b64encode(public).decode() + "\"")
