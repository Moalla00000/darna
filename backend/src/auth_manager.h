#pragma once

#include <Preferences.h>
#include <Arduino.h>

struct Device {
  int id;
  String name;
  bool active;
  bool isAdmin;
};

// Manages authorized door devices stored in ESP32 NVS (Preferences).
// Tokens are stored as SHA-256 hashes (never plaintext).
// Each device has an isAdmin flag; only admins can manage devices.
// Credentials survive reboot and power loss. Revoked slots are reused.
// Initial one-time setup uses a randomly generated setup token.
class AuthManager {
public:
  AuthManager();
  ~AuthManager();

  bool begin();
  bool hasDevices() const;
  bool hasAdmin() const;
  bool verify(const String& token) const;
  bool isAdmin(const String& token) const;
  int listDevices(Device* out, int maxDevices) const;
  // Returns the NVS slot index on success, -1 on failure.
  int addDevice(const String& name, const String& token);
  bool revokeDevice(const String& token);
  bool revokeDeviceById(int id);
  int findSlotByToken(const String& token) const;
  String getDeviceName(int id) const;

  // Initial setup (one-time provisioning)
  bool needsSetup() const;        // no devices and setup not completed
  String generateSetupToken();    // generate + store hash, return plaintext
  bool consumeSetupToken(const String& token); // validate + invalidate
  bool isSetupDone() const;
  String createDeviceToken();     // generate a random bearer token for a new device

  static constexpr int MAX_DEVICES = 8;

private:
  mutable Preferences prefs;
  static constexpr const char* NAMESPACE = "darna_auth";

  int findSlotByHash(const String& tokenHash) const;
  int findReusableSlot() const;
  String sha256Hex(const String& input) const;
  String generateRandomHex(int numBytes) const;
};
