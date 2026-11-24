#pragma once

#include <Arduino.h>
#include <ESP32Servo.h>

// Controls the door servo. Migrated from the original openDoor() sequence:
// sweep 0 -> 140 degrees and back to 0.
class DoorController {
public:
  DoorController(int pin);
  ~DoorController();

  // Open the door: sweep servo open then closed. Returns true on success.
  bool open();

private:
  // Servo calibration and motion timing (adjust for your hardware).
  static constexpr int SERVO_MIN_US = 500;    // Minimum pulse width.
  static constexpr int SERVO_MAX_US = 2400;   // Maximum pulse width.
  static constexpr int SERVO_FREQ_HZ = 50;    // Standard hobby-servo frequency.
  static constexpr int CLOSED_ANGLE = 0;      // Rest/locked position.
  static constexpr int OPEN_ANGLE = 140;      // Unlocked position.
  static constexpr int STEP_DELAY_MS = 15;    // Delay between 1-degree steps.
  static constexpr int SETTLE_DELAY_MS = 500; // Pause before and after the sweep.

  int _pin;
  Servo _servo;
  bool _attached = false;
};
