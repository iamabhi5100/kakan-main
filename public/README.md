# Static assets for backend deployment

## `.well-known/assetlinks.json`

Android App Links require the backend at `staging.api.kakan.co` to serve this file at:

```
GET https://staging.api.kakan.co/.well-known/assetlinks.json
```

**Backend instructions:**

1. Copy the contents of `.well-known/assetlinks.json` to your static file serving path, or
2. Add a route that serves this file at `/.well-known/assetlinks.json`

**Requirements:**

- Return HTTP 200 (no redirects)
- Header: `Content-Type: application/json`
- Publicly readable (no auth)

See `docs/ANDROID_APP_LINKS_BACKEND_SPEC.md` for full details.
