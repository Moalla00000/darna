#include "auth_manager.h"
#include <mbedtls/md.h>
#include <cstdio>
#include <esp_system.h>

AuthManager::AuthManager() {}
AuthManager::~AuthManager() {
  prefs.end();
}

bool AuthManager::begin() {
  return prefs.begin(NAMESPACE, false); // read-write
}

bool AuthManager::hasDevices() const {
  return prefs.getInt("count", 0) > 0;
}

bool AuthManager::hasAdmin() const {
  int count = prefs.getInt("count", 0);
  for (int i = 0; i < count; i++) {
    if (prefs.getBool(("admin" + String(i)).c_str(), false)) return true;
  }
  return false;
}

String AuthManager::sha256Hex(const String& input) const {
  unsigned char output[32];
  mbedtls_md_context_t ctx;
  mbedtls_md_init(&ctx);
  mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), 0);
  mbedtls_md_starts(&ctx);
  mbedtls_md_update(&ctx, (const unsigned char*)input.c_str(), input.length());
  mbedtls_md_finish(&ctx, output);
  mbedtls_md_free(&ctx);

  char hex[65];
  for (int i = 0; i < 32; i++) {
    sprintf(hex + i * 2, "%02x", output[i]);
  }
  hex[64] = '\0';
  return String(hex);
}

String AuthManager::generateRandomHex(int numBytes) const {
  String result;
  result.reserve(numBytes * 2 + 1);
  for (int i = 0; i < numBytes; i++) {
    uint8_t byte = (uint8_t)(esp_random() & 0xFF);
    char hex[3];
    sprintf(hex, "%02x", byte);
    result += hex;
  }
  return result;
}

String AuthManager::generateSetupToken() {
  String token = generateRandomHex(32); // 256-bit
  String hash = sha256Hex(token);
  prefs.putString("setupHash", hash);
  prefs.putBool("setupDone", false);
  return token;
}

String AuthManager::createDeviceToken() {
  return generateRandomHex(32); // 256-bit bearer token
}

bool AuthManager::consumeSetupToken(const String& token) {
  if (token.length() == 0) return false;
  String hash = sha256Hex(token);
  String stored = prefs.getString("setupHash", "");
  if (stored.length() == 0 || stored != hash) return false;
  // Invalidate setup token permanently
  prefs.remove("setupHash");
  prefs.putBool("setupDone", true);
  return true;
}

bool AuthManager::isSetupDone() const {
  return prefs.getBool("setupDone", false);
}

bool AuthManager::needsSetup() const {
  return !hasDevices() && !isSetupDone();
}

bool AuthManager::verify(const String& token) const {
  if (token.length() == 0) return false;
  String tokenHash = sha256Hex(token);
  int count = prefs.getInt("count", 0);
  for (int i = 0; i < count; i++) {
    String storedHash = prefs.getString(("hash" + String(i)).c_str(), "");
    if (storedHash == tokenHash) {
      return prefs.getBool(("active" + String(i)).c_str(), true);
    }
  }
  return false;
}

bool AuthManager::isAdmin(const String& token) const {
  if (token.length() == 0) return false;
  String tokenHash = sha256Hex(token);
  int count = prefs.getInt("count", 0);
  for (int i = 0; i < count; i++) {
    String storedHash = prefs.getString(("hash" + String(i)).c_str(), "");
    if (storedHash == tokenHash) {
      return prefs.getBool(("admin" + String(i)).c_str(), false);
    }
  }
  return false;
}

int AuthManager::listDevices(Device* out, int maxDevices) const {
  int count = prefs.getInt("count", 0);
  int written = 0;
  for (int i = 0; i < count && written < maxDevices; i++) {
    if (!prefs.getBool(("active" + String(i)).c_str(), true)) continue;
    out[written].id = i;
    out[written].name = prefs.getString(("name" + String(i)).c_str(), "");
    out[written].active = true;
    out[written].isAdmin = prefs.getBool(("admin" + String(i)).c_str(), false);
    written++;
  }
  return written;
}

int AuthManager::findSlotByHash(const String& tokenHash) const {
  int count = prefs.getInt("count", 0);
  for (int i = 0; i < count; i++) {
    if (prefs.getString(("hash" + String(i)).c_str(), "") == tokenHash) return i;
  }
  return -1;
}

int AuthManager::findReusableSlot() const {
  int count = prefs.getInt("count", 0);
  for (int i = 0; i < count; i++) {
    if (!prefs.getBool(("active" + String(i)).c_str(), true)) return i;
  }
  return count;
}

int AuthManager::addDevice(const String& name, const String& token) {
  if (token.length() == 0) return -1;
  String tokenHash = sha256Hex(token);
  if (findSlotByHash(tokenHash) >= 0) return -1; // already registered

  int slot = findReusableSlot();
  if (slot < 0 || slot >= MAX_DEVICES) return -1; // Device table is full.
  bool isFirstDevice = !hasAdmin();

  prefs.putString(("name" + String(slot)).c_str(), name);
  prefs.putString(("hash" + String(slot)).c_str(), tokenHash);
  prefs.putBool(("active" + String(slot)).c_str(), true);
  prefs.putBool(("admin" + String(slot)).c_str(), isFirstDevice);

  int count = prefs.getInt("count", 0);
  if (slot == count) prefs.putInt("count", count + 1);
  return slot;
}

bool AuthManager::revokeDevice(const String& token) {
  if (token.length() == 0) return false;
  String tokenHash = sha256Hex(token);
  int count = prefs.getInt("count", 0);
  for (int i = 0; i < count; i++) {
    if (prefs.getString(("hash" + String(i)).c_str(), "") == tokenHash) {
      prefs.putBool(("active" + String(i)).c_str(), false);
      return true;
    }
  }
  return false;
}

bool AuthManager::revokeDeviceById(int id) {
  int count = prefs.getInt("count", 0);
  if (id < 0 || id >= count) return false;
  if (!prefs.getBool(("active" + String(id)).c_str(), true)) return false;
  prefs.putBool(("active" + String(id)).c_str(), false);
  return true;
}

int AuthManager::findSlotByToken(const String& token) const {
  if (token.length() == 0) return -1;
  String tokenHash = sha256Hex(token);
  int count = prefs.getInt("count", 0);
  for (int i = 0; i < count; i++) {
    if (prefs.getString(("hash" + String(i)).c_str(), "") == tokenHash) {
      if (prefs.getBool(("active" + String(i)).c_str(), true)) {
        return i;
      }
    }
  }
  return -1;
}

String AuthManager::getDeviceName(int id) const {
  int count = prefs.getInt("count", 0);
  if (id < 0 || id >= count) return String();
  return prefs.getString(("name" + String(id)).c_str(), "");
}
