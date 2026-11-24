# Darna — Flutter app

Android app for the Darna smart door lock.

See the [root README](../README.md) for hardware, firmware, setup, and usage
instructions.

## Quick start

1. Copy the environment file and set your ESP32 address:
   ```bash
   cp ../.env.example .env
   ```
2. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

Build a release APK with:

```bash
flutter build apk --release --split-per-abi
```
