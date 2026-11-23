#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ESP32Servo.h>

#include "secrets.h"
#include "auth_manager.h"
#include "door_controller.h"

// --- Configuration ---
const int SERVO_PIN = 13;
const unsigned long COOLDOWN_MS = 5000; // prevent accidental/repeated opens

WebServer server(80);
AuthManager auth;
DoorController door(SERVO_PIN);

static unsigned long lastOpenTime = 0;
static volatile bool doorOpening = false;

static void doorOpenTask(void* pvParameters) {
  doorOpening = true;
  door.open();
  doorOpening = false;
  vTaskDelete(NULL);
}

// --- Helpers ---

static String jsonValue(const String& body, const char* key) {
  String search = "\"" + String(key) + "\"";
  int idx = body.indexOf(search);
  if (idx < 0) return String();
  int colon = body.indexOf(':', idx);
  if (colon < 0) return String();
  int start = body.indexOf('"', colon + 1);
  if (start < 0) return String();
  int end = body.indexOf('"', start + 1);
  if (end < 0) return String();
  return body.substring(start + 1, end);
}

static int jsonIntValue(const String& body, const char* key) {
  String search = "\"" + String(key) + "\"";
  int idx = body.indexOf(search);
  if (idx < 0) return -1;
  int colon = body.indexOf(':', idx);
  if (colon < 0) return -1;
  int p = colon + 1;
  while (p < (int)body.length() && (body[p] == ' ' || body[p] == '\t' || body[p] == '"')) {
    p++;
  }
  if (p >= (int)body.length()) return -1;
  int end = p;
  while (end < (int)body.length() && (body[end] >= '0' && body[end] <= '9')) {
    end++;
  }
  if (end == p) return -1;
  return body.substring(p, end).toInt();
}

static String bearerToken() {
  String auth = server.header("Authorization");
  if (auth.startsWith("Bearer ")) return auth.substring(7);
  return String();
}

static void jsonResponse(int code, bool ok, const String& message) {
  String body = "{\"ok\":" + String(ok ? "true" : "false") +
                ",\"message\":\"" + message + "\"}";
  server.send(code, "application/json", body);
}

// Verify bearer token; fills outToken on success.
static bool verifyToken(String& outToken) {
  outToken = bearerToken();
  return outToken.length() > 0 && auth.verify(outToken);
}

// Require a valid admin token. Fills outToken on success.
static bool requireAdmin(String& outToken) {
  if (!verifyToken(outToken)) return false;
  if (!auth.isAdmin(outToken)) {
    jsonResponse(403, false, "Admin token required.");
    return false;
  }
  return true;
}

// ---- Routes ----

void handleOpenDoor() {
  String token;
  if (!verifyToken(token)) {
    jsonResponse(401, false, "Unauthorized: invalid or missing device token");
    return;
  }

  if (doorOpening) {
    jsonResponse(429, false, "Door is already opening.");
    return;
  }

  unsigned long now = millis();
  if (lastOpenTime != 0 && (now - lastOpenTime) < COOLDOWN_MS) {
    jsonResponse(429, false, "Please wait before opening the door again.");
    return;
  }

  lastOpenTime = now;
  xTaskCreate(doorOpenTask, "door_task", 4096, NULL, 1, NULL);
  jsonResponse(200, true, "Door opened");
}

void handleListDevices() {
  String token;
  if (!requireAdmin(token)) return;

  Device devices[AuthManager::MAX_DEVICES];
  int n = auth.listDevices(devices, AuthManager::MAX_DEVICES);

  String body = "{\"ok\":true,\"count\":" + String(n) + ",\"devices\":[";
  for (int i = 0; i < n; i++) {
    if (i > 0) body += ",";
    body += "{\"id\":" + String(devices[i].id) +
            ",\"name\":\"" + devices[i].name +
            "\",\"active\":" + String(devices[i].active ? "true" : "false") +
            ",\"isAdmin\":" + String(devices[i].isAdmin ? "true" : "false") + "}";
  }
  body += "]}";
  server.send(200, "application/json", body);
}

void handleRegisterDevice() {
  String token;
  if (!requireAdmin(token)) return;

  String body = server.arg("plain");
  String name = jsonValue(body, "name");
  String newToken = jsonValue(body, "token");
  if (name.length() == 0 || newToken.length() == 0) {
    jsonResponse(400, false, "name and token are required");
    return;
  }

  int slot = auth.addDevice(name, newToken);
  if (slot >= 0) {
    jsonResponse(200, true, "Device registered");
  } else {
    jsonResponse(400, false, "Could not register device (duplicate or full)");
  }
}

void handleRevokeDevice() {
  String token;
  if (!requireAdmin(token)) return;

  String body = server.arg("plain");
  int callerSlot = auth.findSlotByToken(token);

  int targetId = jsonIntValue(body, "id");
  if (targetId >= 0) {
    if (callerSlot == targetId) {
      jsonResponse(400, false, "Cannot revoke your own device.");
      return;
    }
    if (auth.revokeDeviceById(targetId)) {
      jsonResponse(200, true, "Device revoked");
    } else {
      jsonResponse(404, false, "Device not found or already revoked");
    }
    return;
  }

  String targetToken = jsonValue(body, "token");
  if (targetToken.length() == 0) {
    jsonResponse(400, false, "Device ID or token is required");
    return;
  }

  // Prevent admin from revoking itself.
  if (targetToken == token) {
    jsonResponse(400, false, "Cannot revoke your own device.");
    return;
  }

  if (auth.revokeDevice(targetToken)) {
    jsonResponse(200, true, "Device revoked");
  } else {
    jsonResponse(404, false, "Device not found or already revoked");
  }
}

void handleVerifyToken() {
  String token;
  if (!verifyToken(token)) {
    jsonResponse(401, false, "Invalid or unauthorized device token.");
    return;
  }
  int slot = auth.findSlotByToken(token);
  String name = auth.getDeviceName(slot);
  bool isAdmin = auth.isAdmin(token);
  String body = "{\"ok\":true,\"valid\":true,\"deviceId\":" + String(slot) +
                ",\"deviceName\":\"" + name +
                "\",\"isAdmin\":" + String(isAdmin ? "true" : "false") + "}";
  server.send(200, "application/json", body);
}

// One-time initial setup: register the first (admin) device using a setup
// token printed to Serial on first boot. No bearer auth required.
void handleSetupRegister() {
  String body = server.arg("plain");
  String setupToken = jsonValue(body, "setupToken");
  String deviceName = jsonValue(body, "deviceName");

  if (setupToken.length() == 0 || deviceName.length() == 0) {
    jsonResponse(400, false, "setupToken and deviceName are required");
    return;
  }

  // Setup only valid when no devices exist and setup not completed.
  if (!auth.needsSetup()) {
    jsonResponse(403, false, "Setup already completed or not required.");
    return;
  }

  // Validate and consume the setup token (one-time use).
  if (!auth.consumeSetupToken(setupToken)) {
    jsonResponse(401, false, "Invalid setup token.");
    return;
  }

  // Generate the new device's bearer token and register it as admin.
  String deviceToken = auth.createDeviceToken();
  int slot = auth.addDevice(deviceName, deviceToken);
  if (slot < 0) {
    jsonResponse(400, false, "Could not register device.");
    return;
  }

  String response = "{\"success\":true,\"deviceId\":\"device-" +
                    String(slot + 1) + "\",\"deviceToken\":\"" + deviceToken +
                    "\"}";
  server.send(200, "application/json", response);
}

void setup() {
  Serial.begin(115200);
  delay(200);

  // --- WiFi + static IP (credentials from gitignored secrets.h) ---
  if (!WiFi.config(LOCAL_IP, GATEWAY, SUBNET, PRIMARY_DNS, SECONDARY_DNS)) {
    Serial.println("Static IP configuration failed!");
  }
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // --- Auth (NVS) ---
  if (!auth.begin()) {
    Serial.println("Failed to open NVS auth namespace!");
  }

  // --- Initial setup: generate and print setup token once ---
  if (auth.needsSetup()) {
    String setupToken = auth.generateSetupToken();
    Serial.println();
    Serial.println("========================================");
    Serial.println("DARNA INITIAL SETUP");
    Serial.print("Setup token: ");
    Serial.println(setupToken);
    Serial.println("Enter this token in the Darna app.");
    Serial.println("This token is valid only for initial setup.");
    Serial.println("========================================");
    Serial.println();
  }

  // --- Routes ---
  server.on("/api/v1/door/open", HTTP_POST, handleOpenDoor);
  server.on("/api/v1/devices", HTTP_GET, handleListDevices);
  server.on("/api/v1/devices/register", HTTP_POST, handleRegisterDevice);
  server.on("/api/v1/devices/revoke", HTTP_POST, handleRevokeDevice);
  server.on("/api/v1/setup/register", HTTP_POST, handleSetupRegister);
  server.on("/api/v1/auth/verify", HTTP_POST, handleVerifyToken);
  server.on("/api/v1/auth/verify", HTTP_GET, handleVerifyToken);

  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
}
