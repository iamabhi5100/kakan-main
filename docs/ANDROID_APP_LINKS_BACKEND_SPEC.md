# Android App Links – Backend Spec (for Backend Team)

So that shared post links like  
`https://staging.api.kakan.co/v1/posts/user-posts/854c783c-1432-4c06-9f73-1bd402125706/`  
**open directly in the Kakan Android app** (instead of the browser), the backend must serve **one file** on the API domain.

---

## Values from mobile team (use these in assetlinks.json)

| Field | Value |
|-------|--------|
| **Package name** | `com.example.kakan` |
| **SHA-256 fingerprint (release / Play Store)** | `8A:18:85:EF:89:40:CB:CE:F1:92:76:BB:D0:F0:EB:DF:A9:C2:81:72:88:59:FF:15:06:91:AD:5F:78:A2:DA:35` |

**Ready-to-use JSON** – copy this as the response body for `GET https://staging.api.kakan.co/.well-known/assetlinks.json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.kakan",
      "sha256_cert_fingerprints": [
        "8A:18:85:EF:89:40:CB:CE:F1:92:76:BB:D0:F0:EB:DF:A9:C2:81:72:88:59:FF:15:06:91:AD:5F:78:A2:DA:35"
      ]
    }
  }
]
```

---

## 1. What the backend must serve

| Item | Value |
|------|--------|
| **URL** | `https://staging.api.kakan.co/.well-known/assetlinks.json` |
| **Method** | GET |
| **Response** | JSON (see section 3) |

This is the **Digital Asset Links** file Android uses to verify that your app is allowed to open links for `staging.api.kakan.co`.

---

## 2. Server requirements

- The URL must be **HTTPS** (already the case for `staging.api.kakan.co`).
- **No redirects** – the server must return `200 OK` with the JSON body directly for this URL (no 301/302 to another URL).
- **Content-Type** – response header should be:  
  `Content-Type: application/json`
- The file must be **publicly readable** (no auth required). Android’s servers will request it to verify the app.

---

## 3. Exact JSON format

The response body for `GET /.well-known/assetlinks.json` must be **exactly** this structure (with real values from the app team – see section 4):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.kakan",
      "sha256_cert_fingerprints": [
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
      ]
    }
  }
]
```

**Notes:**

- `package_name` – must be exactly the app’s Android package name (see section 4).
- `sha256_cert_fingerprints` – array of SHA-256 fingerprints of the **signing certificate(s)** used to sign the APK/AAB that users install. One entry for debug, one (or more) for release if you want both to open the link (see section 4).
- Colons in the fingerprint are optional; Android accepts both `AA:BB:CC:...` and `AABBCC...`.
- No extra fields or comments in the JSON.

---

## 4. What the app team must give to the backend

The backend needs **two values** from the app (Android) team:

### A) Package name

- **Value to use:** `com.example.kakan`  
- (If the app team changes the package name in `build.gradle.kts` in the future, this value must be updated in `assetlinks.json`.)

### B) SHA-256 certificate fingerprint(s)

Android verifies the app using the certificate that **signed** the app. The backend must put that certificate’s SHA-256 fingerprint in `sha256_cert_fingerprints`.

**How the app team gets the fingerprint:**

**Debug builds (for testing):**

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

In the output, find the line **“SHA256:”** and copy the hex value (e.g. `AA:BB:CC:DD:...`). That is the **debug** fingerprint.

**Release builds (for Play Store / production):**

```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your-key-alias
```

Use the keystore and alias that you use to sign the release APK/AAB. Again, copy the **SHA256** value. That is the **release** fingerprint.

**Example (if your Play Store keystore is `android/app/keystore.jks` with alias `upload`):**

```bash
keytool -list -v -keystore android/app/keystore.jks -alias upload
```

Enter the keystore password when prompted. In the output, find the line **"SHA256:"** (or "Certificate fingerprint (SHA-256):") and copy that entire value (e.g. `AA:BB:CC:DD:EE:...`). That is the value to give to the backend.

**If you want both debug and release links to open the app**, the backend should include **both** fingerprints in the array:

```json
"sha256_cert_fingerprints": [
  "DEBUG_SHA256_FINGERPRINT_HERE",
  "RELEASE_SHA256_FINGERPRINT_HERE"
]
```

The backend team only needs to paste the strings they receive from the app team; they don’t need to run `keytool` themselves.

---

## 5. Example with fake fingerprints

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.kakan",
      "sha256_cert_fingerprints": [
        "14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5:91",
        "BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA"
      ]
    }
  }
]
```

(Replace with real fingerprints from the app team.)

---

## 6. Summary checklist for backend

- [ ] Add a route (or static file) so that  
  `GET https://staging.api.kakan.co/.well-known/assetlinks.json`  
  returns HTTP 200 with the JSON body.
- [ ] No redirect (301/302) for this URL.
- [ ] Response header: `Content-Type: application/json`.
- [ ] JSON body: array with one object containing `relation`, `target`, `target.namespace`, `target.package_name`, `target.sha256_cert_fingerprints` as above.
- [ ] Get from app team: **package name** (`com.example.kakan`) and **SHA-256 fingerprint(s)** (debug and/or release) and put them in the JSON.

---

## 7. How to verify (after backend deploys)

1. Open in a browser:  
   `https://staging.api.kakan.co/.well-known/assetlinks.json`  
   You should see the JSON (same as in section 3) with no redirect.
2. On an Android device/emulator with the Kakan app installed, tap a link like:  
   `https://staging.api.kakan.co/v1/posts/user-posts/854c783c-1432-4c06-9f73-1bd402125706/`  
   (e.g. from Notes or WhatsApp.)
3. If verification succeeds, the app should open directly (no “Open with” dialog). If verification fails, Android may open the link in the browser or show “Open with”.

---

## 8. Links for backend reference

- [Google – Verify Android App Links](https://developer.android.com/training/app-links/verify-android-applinks)
- [Digital Asset Links – format](https://developers.google.com/digital-asset-links/v1/getting-started)
