#include "door_controller.h"

DoorController::DoorController(int pin) : _pin(pin) {}
DoorController::~DoorController() {
  if (_attached) _servo.detach();
}

bool DoorController::open() {
  Serial.println("Opening door...");

  _servo.attach(_pin, SERVO_MIN_US, SERVO_MAX_US);
  _servo.setPeriodHertz(SERVO_FREQ_HZ);
  _attached = true;

  _servo.write(CLOSED_ANGLE);
  delay(SETTLE_DELAY_MS);

  for (int angle = CLOSED_ANGLE; angle <= OPEN_ANGLE; angle++) {
    _servo.write(angle);
    delay(STEP_DELAY_MS);
  }

  delay(SETTLE_DELAY_MS);

  for (int angle = OPEN_ANGLE; angle >= CLOSED_ANGLE; angle--) {
    _servo.write(angle);
    delay(STEP_DELAY_MS);
  }

  _servo.detach();
  _attached = false;

  Serial.println("Door opened");
  return true;
}
