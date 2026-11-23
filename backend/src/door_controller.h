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
  int _pin;
  Servo _servo;
  bool _attached = false;
};
