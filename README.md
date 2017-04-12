# Sensor Node Testing

The SensorNodeTest.device.nut file includes a small test suite for testing sensors on the Sensor Node. This code currently supports Imp001 and Imp004 kits. Included in the device.nut file is a class that contains the tests (see documentation below for details) as well as some example code including setup and runtime code.  Please adjust the example code to run the desired tests.

## Sensor Node Test Class

### Class dependencies:

* HTS221
* LPS22HB
* LIS3DH
* Onwire

### Class Usage

#### Constructor: SensorNodeTest(*enableAccelInt, enablePressInt*)

The constructor takes two arguments to instantiate the class: the booleans *enableAccelInt* and *enablePressInt*, these flags will be used when testing interrupts.

```
// Interrupt settings
local ENABLE_ACCEL_INT = false;
local ENABLE_PRESS_INT = true;

// Initialize test class
node <- SensorNodeTest(ENABLE_ACCEL_INT, ENABLE_PRESS_INT);
```

### Class Methods

#### scanSensorI2C()

Scans the onboard sensor i2c bus and logs addresses for the sensors it finds.

```
node.scanSensorI2C();
```

#### scanRJ45I2C()

Scans the RJ45 i2c bus and logs addresses for the sensors it finds.

```
node.scanRJ45I2C();
```

#### testSleep()

Tests the power consumption during sleep.  Boots at full power for 10s, then goes into a deep sleep for 20s.

```
node.testSleep();
```

#### testTempHumid()

Configures the sensor in one shot mode, takes a reading and logs the result.

```
node.testTempHumid();
```

#### testAccel()

Configures the sensor, gets a reading and logs the result.

```
node.testAccel();
```

#### testPressure()

Configures the sensor in one shot mode, takes a reading and logs the result.

```
node.testPressure();
```


#### testOnewire();

Scans for Onewire bus for devices.  If devices are found logs the id for the device.

```
node.testOnewire();
```

#### testLEDs()

Turns on the blue LED then the green LED 5 sec later, then turns off both LEDs.

```
node.testLEDs();
```

### testInterrupts(*[testIntWakeUp]*)

Enables the interrupts based on the flags passed into the constructor. When an interrupt is detected it will be logged. Currently only the pressure and accelerometer interrupts are tested. If the boolean *testIntWakeUp* parameter is `true` the device is put to sleep and wakes when an interrupt is detected. The default value for *testIntWakeUp* is false.

```
local TEST_WAKE_INT = true;

node.testInterrupts(TEST_WAKE_INT);
```