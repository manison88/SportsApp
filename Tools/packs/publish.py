#!/usr/bin/env python3
"""Uploads dist/packs to the R2 bucket: new pack files first, manifest.json last, so the app never sees a manifest
that points at a pack that is not there yet.

  pip install boto3
  R2_ACCOUNT_ID=... R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=... python3 Tools/packs/publish.py [--bucket witness-packs] [--dir dist/packs]

Pack files are named by content hash, so they are immutable (cached for a year); only manifest.json is short-lived.
"""
import argparse, json, os, sys

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bucket", default="witness-packs")
    ap.add_argument("--dir", default=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "dist", "packs"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    try:
        import boto3
    except ImportError:
        sys.exit("pip install boto3")
    account, key, secret = (os.environ.get(k) for k in ("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY"))
    if not (account and key and secret) and not args.dry_run:
        sys.exit("set R2_ACCOUNT_ID, R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY")
    s3 = None if args.dry_run else boto3.client("s3", endpoint_url=f"https://{account}.r2.cloudflarestorage.com",
                                                aws_access_key_id=key, aws_secret_access_key=secret, region_name="auto")
    existing = set()
    if s3:
        for page in s3.get_paginator("list_objects_v2").paginate(Bucket=args.bucket):
            existing |= {o["Key"] for o in page.get("Contents", [])}
    envelope = json.load(open(os.path.join(args.dir, "manifest.json")))
    packs = json.loads(envelope["body"])["packs"]
    new = [p for p in packs if p["path"] not in existing]
    print(f"{len(packs)} packs in the manifest, {len(new)} to upload ({sum(p['bytes'] for p in new) / 1e6:.1f} MB)")
    for p in new:
        if s3:
            s3.upload_file(os.path.join(args.dir, p["path"]), args.bucket, p["path"],
                           ExtraArgs={"ContentType": "application/json", "CacheControl": "public, max-age=31536000, immutable"})
    if s3:
        s3.upload_file(os.path.join(args.dir, "manifest.json"), args.bucket, "manifest.json",
                       ExtraArgs={"ContentType": "application/json", "CacheControl": "public, max-age=300"})
        # Packs the manifest no longer lists are dropped after the new manifest is live.
        keep = {p["path"] for p in packs} | {"manifest.json"}
        stale = [k for k in existing if k not in keep]
        for k in stale:
            s3.delete_object(Bucket=args.bucket, Key=k)
        print(f"uploaded {len(new)} packs and the manifest; removed {len(stale)} old packs")

if __name__ == "__main__":
    main()
