# PhotoMagic — Flutter (web + Android)

A Flutter application mirroring the PhotoMagic **web app exactly**: the same
login contract bolted straight onto the Realtime Database REST API (v2 PBKDF2 /
legacy sha256 hashes, suspension and expiry rules, 30 s monitor), the same A4
photo-grid studio (items with pencil-edit, paper preview, 300 DPI saves) and
the same Word (.docx) export driven through the native OS share sheet.

Everything is built **through GitHub Actions**:

- `web.yml` → builds the Flutter web bundle and publishes it to **GitHub Pages**
  (https://abdullah2025jalal.github.io/photomagic-flutter/).
- `deploy-web.yml` → dispatch-only; builds the same bundle and publishes it to
  **Firebase Hosting** → `https://photomagic-flutter.web.app` as soon as the
  `FIREBASE_SERVICE_ACCOUNT` secret (project `photomagic-2a69e`) is added.
- `android.yml` → builds the release APK as a downloadable artifact (the login
  is REST-based, so the APK needs **no** Firebase secret at all).
