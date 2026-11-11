---
name: file-uploads
description: "Accept file uploads safely — magic-byte type checks, size caps, filename sanitization, presigned S3/R2 URLs. Use when building or reviewing an upload endpoint for spoofing or traversal bugs."
source: vibeship-spawner-skills (Apache 2.0)
risk: unknown
---

# File Uploads & Storage

Four things go wrong with uploads: the file is not what it claims, it is bigger than you
planned for, its name escapes the directory you meant, or it lands somewhere readable by
the wrong people. Everything below is one of those four.

## Never trust the declared type

The browser-sent `Content-Type` and the extension are both attacker-controlled. Sniff the
magic bytes and compare against an **allowlist** of accepted types.

```bash
# a GIF renamed to .png — the extension lies, the bytes do not
$ printf 'GIF89a' > fake.png && file --mime-type fake.png
fake.png: image/gif
```

```python
import magic  # python-magic
ALLOWED = {"image/jpeg", "image/png", "image/webp", "application/pdf"}

head = upload.read(2048); upload.seek(0)
detected = magic.from_buffer(head, mime=True)
if detected not in ALLOWED:
    raise UnsupportedMediaType(f"rejected {detected}")
```

Then derive the stored extension **from `detected`**, never from the uploaded name.
Allowlist, not blocklist: a blocklist of `.php,.exe,.sh` misses `.phtml`, `.svg` (which
carries script), and whatever is next.

## Cap the size at the edge, not in your handler

A limit checked after the body is buffered has already spent the memory.

- Nginx `client_max_body_size 10m;` / Apache `LimitRequestBody`
- Express `express.json({limit:'10mb'})` and `multer({limits:{fileSize:10*1024*1024}})`
- FastAPI/Starlette: stream with `UploadFile` and count bytes as they arrive — bail past
  the cap rather than reading `await file.read()` whole
- For presigned uploads the cap belongs **in the policy** (`content-length-range`), since
  the client talks to S3 directly and never passes your server

Reject on exceed; do not silently truncate — a truncated image is a corrupt file you will
debug later.

## Never build a path from a user-supplied name

Store under a name **you** generate; keep the original only as a display label in the DB.

```python
import uuid, pathlib
ext = MIME_TO_EXT[detected]                 # from sniffed type, not the upload
key = f"uploads/{user_id}/{uuid.uuid4().hex}{ext}"
display_name = pathlib.PurePosixPath(original).name   # strips ../ and any directory part
```

`../`, absolute paths, NUL bytes, Unicode lookalikes, and Windows reserved names (`CON`,
`PRN`, `AUX`) all stop mattering once the stored key is a UUID. If you must keep user
names on disk, resolve the final path and assert it is still inside the upload root —
checking the string for `..` before normalization is not enough.

## Presigned URLs over proxying

Streaming a 2 GB upload through the app server ties up a worker, burns memory, and buys
nothing. Issue a presigned PUT/POST and let the client talk to storage.

```python
url = s3.generate_presigned_url(
    "put_object",
    Params={"Bucket": BUCKET, "Key": key, "ContentType": detected},
    ExpiresIn=300,          # minutes, not hours
)
```

Rules that make this safe:

- **Short expiry.** 5–15 minutes. The URL *is* the credential — anyone holding it can write.
- **Pin the key server-side.** Never let the client choose the object key, or one user
  overwrites another's object.
- **Pin `ContentType` and a `content-length-range`** in the policy, so the cap and type
  check you did at issue time still bind at upload time.
- **`Cache-Control: private, no-store`** on responses carrying presigned URLs — a shared
  cache or CDN that stores one hands the credential to the next requester.
- **Verify after the fact.** The client may never complete, or may upload something else.
  Confirm the object exists and re-sniff its type on the storage-event callback before
  marking the record usable.

Cloudflare R2 is S3-API compatible: the same boto3 call works against an R2 endpoint, so
treat the two identically except for `endpoint_url`.

## Serving back

Private bucket + presigned GET, or a signed CDN URL. If uploads must be public, put them
on a **separate origin** from your app — an HTML or SVG file served from your own domain
runs with your cookies. Set `Content-Disposition: attachment` and
`X-Content-Type-Options: nosniff` for anything you did not generate yourself.

## Review checklist

| Check | Why it bites |
|---|---|
| Type decided by magic bytes against an allowlist | Extension and `Content-Type` are attacker-controlled |
| Size capped at proxy / policy, before buffering | Cap in the handler has already spent the memory |
| Stored key generated server-side (UUID) | Kills path traversal and cross-user overwrite at once |
| Presigned expiry ≤15 min, key + type + size pinned | The URL is a bearer credential |
| Presigned URLs marked `no-store` | Cached once, reusable by anyone |
| Object re-verified on completion callback | Issue-time checks do not bind what actually landed |
| Public uploads on a separate origin | Same-origin HTML/SVG runs with your cookies |
