#include "door_controller.h"

DoorController::DoorController(int pin) : _pin(pin) {}
DoorController::~DoorController() {
  if (_attached) _servo.detach();
}

bool DoorController::open() {
  Serial.println("Opening door...");

  _servo.attach(_pin, 500, 2400);
  _servo.setPeriodHertz(50);
  _attached = true;

  _servo.write(0);
  delay(500);

  for (int angle = 0; angle <= 140; angle++) {
    _servo.write(angle);
    delay(15);
  }

  delay(500);

  for (int angle = 140; angle >= 0; angle--) {
    _servo.write(angle);
    delay(15);
  }

  _servo.detach();
  _attached = false;

  Serial.println("Door opened");
  return true;
}
