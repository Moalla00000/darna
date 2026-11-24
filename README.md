# Darna

**Darna** is a self-hosted smart door lock. An ESP32 board drives a servo that
unlocks your door, and a Flutter Android app lets you open it from your phone
over your home Wi-Fi. Everything stays on your local network — there is no
cloud service and no internet dependency.

The name *Darna* means "our house".

> **DIY project, use at your own risk.** Darna is not a replacement for a
> certified lock. Always keep a physical key or another way into your home.

---

## Features

- **Open the door from your phone** with one tap.
- **One-time initial setup** using a setup token printed to the ESP32 Serial
  Monitor. The first phone becomes the admin device.
- **Token-based pairing** — the admin generates an access token for each
  family member's phone and shares it out of band.
- **Add and revoke devices** from the app. Revocation takes effect immediately.
- **Local-only** — the ESP32 runs an HTTP server on your Wi-Fi; no cloud account.
- **Dark mode** and a simple, Material 3 interface.

---

## Screenshots

_Add screenshots here. Suggested images live in `docs/images/`._

| Home | Authorized devices | Setup |
| --- | --- | --- |
| _screenshot_ | _screenshot_ | _screenshot_ |

---

## How it works

```
┌────────────────┐    Wi-Fi (HTTP/JSON)    ┌─────────────────────┐   PWM    ┌──────────────┐
│  Flutter app   │ ──────────────────────> │  ESP32 WebServer    │ ───────> │ Servo + lock │
│  (Android)     │ <────────────────────── │  AuthManager (NVS)  │          │  mechanism   │
└────────────────┘    JSON responses       └─────────────────────┘          └──────────────┘
```

1. The phone sends `POST /api/v1/door/open` with a bearer token.
2. The ESP32 hashes the token and checks it against the active devices stored
   in its non-volatile storage (NVS).
3. If the token is valid, the ESP32 starts a background task that sweeps the
   servo from 0° to 140° and back, then returns to the HTTP loop.
4. The app shows "Opening Door..." for about 5.2 seconds to match the physical
   movement.

The ESP32 is the authority: tokens are stored only as SHA-256 hashes, and the
phone keeps its own token in encrypted storage.

---

## Hardware

| Part | Notes |
| --- | --- |
| ESP32 development board | ESP32 DevKit V1 / ESP32-WROOM-32 or similar. |
| Hobby servo | SG90 for a light latch, MG996R for more torque. |
| External 5 V power supply | Recommended: ≥ 1 A for SG90, ≥ 2 A for MG996R. |
| Jumper wires | For signal, power, and ground. |
| USB cable | Data-capable, to flash the ESP32. |
| Door latch/lock linkage | A bracket or 3D-printed part that couples the servo to your lock. |
| Android phone | Any phone supported by the installed Flutter SDK. |

**Important:** power the servo from a separate 5 V supply, not from a GPIO pin.
Connect the servo ground and the ESP32 ground together (common ground).

### Wiring

| Servo wire | Typical color | Connect to |
| --- | --- | --- |
| Signal | Orange or yellow | ESP32 **GPIO 13** |
| VCC / + | Red | External **5 V +** |
| GND / − | Brown or black | **Common ground** (ESP32 GND + power supply GND) |

If you use a small SG90 and power it from the ESP32's 5 V pin, the board may
brown out and reboot when the servo moves. An external 5 V supply is safer.

The servo pin and motion values are defined in
`backend/src/main.cpp` and `backend/src/door_controller.h`:

- `SERVO_PIN = 13`
- `OPEN_ANGLE = 140`, `CLOSED_ANGLE = 0`
- `COOLDOWN_MS = 5000`

Adjust these if your mechanism needs different angles or timing.

---

## Software requirements

- **PlatformIO** — either the VS Code PlatformIO IDE extension or PlatformIO
  Core (`pio`) on the command line.
- **Flutter SDK** (this project was built with Flutter 3.47 / Dart 3.13) and
  the Dart tooling that ships with it.
- **Android Studio** or the Android SDK + Java 17, so Flutter can build the APK.
- A USB cable and, on Windows, the correct USB-to-serial driver (CP210x or
  CH340, depending on your board).

Verify your tools:

```bash
pio --version
flutter doctor
```

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/Moalla00000/darna.git
cd darna
```

### 2. Configure the ESP32

Copy the example secrets file and edit it:

```bash
cp backend/include/secrets.example.h backend/include/secrets.h
```

Open `backend/include/secrets.h` and set:

- `WIFI_SSID` and `WIFI_PASSWORD` — your **2.4 GHz** Wi-Fi network. The ESP32
  does not support 5 GHz networks.
- `LOCAL_IP` — the static IP you want the ESP32 to use (default
  `192.168.1.200`).
- `GATEWAY` — your router's LAN IP (default `192.168.1.1`).
- `SUBNET` — usually `255.255.255.0`.
- `PRIMARY_DNS` / `SECONDARY_DNS` — optional for local-only use.

`secrets.h` is gitignored. Never commit it.

**Static IP note:** choose an address in your router's subnet, outside the
DHCP pool, or reserve it for the ESP32 in your router. If the address changes,
update `frontend/.env` to match.

### 3. Flash the ESP32

Connect the board over USB, then:

```bash
cd backend
pio run --target erase
pio run --target upload
pio device monitor --baud 115200
```

`monitor_speed = 115200` is already set in `platformio.ini`, so
`pio device monitor` works without the `--baud` flag too.

**Linux — serial permission error (`Permission denied`):**

```bash
sudo usermod -aG dialout "$USER"
```

Log out and back in (or reboot) for the group change to apply. As a temporary
workaround you can use `sudo chmod a+rw /dev/ttyUSB0` (replace with your port).

**Windows — driver / port:** install the CP210x or CH340 driver for your board,
then check Device Manager for the COM port. Use `pio device list` to confirm
PlatformIO can see it.

**Upload fails with "Failed to connect":** hold the **BOOT** button, press and
release **EN/RST**, then release **BOOT** to put the board in download mode and
retry the upload. Also check that no other program is using the serial port.

The Serial Monitor should show the Wi-Fi connection and the IP address:

```
Connected!
IP Address: 192.168.1.200
```

### 4. Confirm the ESP32 IP address

The firmware uses the static `LOCAL_IP` from `secrets.h`. After boot, the
Serial Monitor prints the actual address. Make sure it is reachable from your
phone's browser or with `ping` from a computer on the same Wi-Fi.

If you prefer DHCP instead of a static IP, remove or comment out the
`WiFi.config(...)` call in `backend/src/main.cpp`, reflash, and read the
assigned address from the Serial Monitor.

### 5. Configure the Flutter app

From the repository root (`cd ..` if you are still in `backend/`):

```bash
cp .env.example frontend/.env
```

Edit `frontend/.env` and set the ESP32 address (no trailing slash):

```dotenv
ESP32_BASE_URL=http://192.168.1.200
```

This must match `LOCAL_IP` in `backend/include/secrets.h`. The app loads this
file as a bundled asset, so rebuild the app after changing it.

### 6. Run and build the app

```bash
cd frontend
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --release --split-per-abi
```

The APKs are written to:

```
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

Install the one that matches your phone (most modern phones use
`arm64-v8a`) with `adb install <path>`, or copy it to the phone and open it.

**Release signing:** by default a release build uses the debug signing key so
it can be installed locally. For a real release, from the `frontend/`
directory, create a keystore:

```bash
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `android/key.properties.example` to `android/key.properties` and
fill in the values. Place the keystore where `storeFile` points (relative paths
are resolved from `frontend/android/app/`; the command above puts it there as
`upload-keystore.jks`). Never commit `key.properties` or the keystore — both
are gitignored.

### 7. Initial setup and pairing

1. Power the ESP32 and open the Serial Monitor at **115200** baud.
2. On first boot (no devices configured), it prints a 64-character setup token:

   ```
   ========================================
   DARNA INITIAL SETUP
   Setup token: <64-character token>
   Enter this token in the Darna app.
   ========================================
   ```

3. Open the Darna app. It shows the **Initial Setup** screen because this phone
   has no token yet.
4. Enter the setup token and a name for this phone, then tap **Register this
   device**. This phone becomes the **admin** device.

The setup token is one-time: it is invalidated after a successful setup. If you
miss it before completing setup, press **EN/RST** to reboot and a new token is
printed (the old one stops working).

### 8. Add and remove devices

**Add a device:**

1. On the admin phone, open **Settings → Authorized Devices → Add device**.
2. Enter a name (for example, "Sara's Phone") and tap **Generate Token & Add
   Device**.
3. Copy or share the generated 64-character token.
4. On the other phone, open the Darna app, paste the token into the Setup
   screen, and enter a name. Tap **Register this device**.

**Remove a device:**

- On the admin phone, open **Authorized Devices**, then tap the trash icon or
  swipe the device card left and confirm.
- The device loses access immediately. The admin device itself is locked and
  cannot be revoked from the app.
- Up to **8 devices** can be registered.

---

## Troubleshooting

| Problem | What to check |
| --- | --- |
| The app cannot reach the ESP32 | The phone and ESP32 must be on the **same Wi-Fi network**. Guest networks and "AP isolation" block device-to-device traffic. Disable VPN/mobile data for the test. |
| The ESP32 does not connect to Wi-Fi | It only supports **2.4 GHz**. Check the SSID/password in `secrets.h`, the router's MAC filtering, and the Serial Monitor output. |
| The serial monitor shows garbled text | Use **115200** baud, select the correct port, and close any other program using that port. `monitor_speed` is already set in `platformio.ini`. |
| "Failed to connect" in the app | `ESP32_BASE_URL` does not match the ESP32's actual IP, the ESP32 is offline, or the phone is on a different network. Ping the IP from a computer on the same Wi-Fi. |
| A token is not accepted | The setup token was already used or invalidated by a reboot; the device was revoked; there is a stray space from copy/paste; or the device table is full (8 devices). |
| The door does not open | Check servo power and common ground, the signal wire on **GPIO 13**, and the Serial Monitor. The 5-second cooldown and the "already opening" guard can reject a second request. The app reports success after 5.2 s even if the servo is physically stuck (there is no door sensor). |
| The app build fails because `.env` is missing | Run `cp .env.example frontend/.env` from the repo root before building. |
| `pio` is not found | Install PlatformIO Core (`pip install platformio`) or use the VS Code PlatformIO extension. |
| Android build fails | Run `flutter doctor` and install the missing Android SDK / Java 17 components. |

---

## Security notes and known limitations

- **Local network only.** Do not port-forward the ESP32 or expose it to the
  internet. It is designed for a trusted home LAN.
- **Plain HTTP.** Traffic between the phone and the ESP32 is unencrypted. Use a
  WPA2/WPA3 network you trust; avoid public or guest Wi-Fi. Someone who can
  sniff the LAN and capture a bearer token could open the door.
- **Bearer tokens.** Device tokens are 256-bit random values, stored as SHA-256
  hashes in the ESP32's NVS. The phone stores its own token in encrypted
  storage. Device bearer tokens are never logged by the firmware; only the
  one-time setup token is printed to Serial by design.
- **One-time setup token.** The initial setup token is printed to Serial and
  invalidated after use. It is the physical-presence bootstrap.
- **No TLS, no rate limiting, no door sensor.** The system is open-loop: the
  app infers success from timing, not from a sensor. A jammed or disconnected
  servo is not detected.
- **Tokens do not expire.** Revoke and re-pair a phone to rotate its token.
- **Minimal JSON parser.** The firmware uses a small hand-rolled parser; avoid
  quotes and backslashes in device names.
- **Physical access.** NVS is not encrypted by default. Someone with physical
  access to the ESP32 can extract stored token hashes; enable ESP32 flash
  encryption and secure boot if your threat model requires it.
- **Admin recovery.** There is no in-app "reset admin" flow. If the admin phone
  is lost, erase the ESP32 flash with `pio run --target erase`, re-upload the
  firmware with `pio run --target upload`, and set up again. This removes all
  paired devices.
- **Maximum 8 devices.** Revoked slots are reused.
- **Android application ID.** The app currently uses `com.example.darna`.
  Change it to your own reverse-domain ID before publishing to an app store
  (this changes the installed app's identity and prevents in-place updates).
- **Keep secrets out of Git.** `backend/include/secrets.h`, `frontend/.env`,
  `key.properties`, and keystores are gitignored. Only the `.example` files
  should be committed.
- **Use at your own risk.** This is a DIY project, not a certified security
  product. Keep a physical key.

---

## Project structure

```
darna/
├── backend/                     ESP32 firmware (PlatformIO + Arduino)
│   ├── include/
│   │   ├── secrets.example.h    Template for Wi-Fi + static IP config
│   │   └── secrets.h            Your real config (gitignored)
│   ├── src/
│   │   ├── main.cpp             HTTP server, routes, Wi-Fi, setup token
│   │   ├── auth_manager.h/.cpp  NVS-backed device/token storage
│   │   └── door_controller.h/.cpp  Servo sweep
│   ├── test/                    Firmware test notes
│   └── platformio.ini
├── frontend/                    Flutter Android app
│   ├── lib/
│   │   ├── core/                Constants and theme
│   │   ├── features/            Splash, setup, home, settings, devices
│   │   ├── services/            HTTP client and secure token storage
│   │   ├── widgets/             Status chip and action button
│   │   └── main.dart
│   ├── android/                 Android project + network config
│   ├── assets/                  Launcher icon
│   ├── test/                    Flutter widget test
│   ├── .env                     Your app config (gitignored)
│   └── pubspec.yaml
├── docs/images/                 Screenshots for this README
├── .env.example                 Template for frontend/.env
├── .gitignore
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the short
version: keep changes small, never commit secrets, run `flutter analyze` and
`pio run` before opening a pull request, and describe any behavior changes.

---

## License

MIT — see [LICENSE](LICENSE).
