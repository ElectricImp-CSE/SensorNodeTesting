# Sensor Node Testing

The SensorNodeTest.device.nut file includes a small test suite for testing sensors on the Sensor Node. This code currently supports Imp001 and Imp004 kits. Included in the device.nut file is a class that contains the tests (see documentation below for details) as well as some example code including setup and runtime code.  Please adjust the example code to run the desired tests.

## Sensor Node Tests Class

### Class dependencies:

* HTS221
* LPS22HB
* LIS3DH
* Onwire

### Class Usage

#### Constructor: SensorNodeTests(*enableAccelInt, enablePressInt, enableTempHumidInt, intHandler*)

The constructor takes 4 arguments to instantiate the class: the booleans *enableAccelInt*, *enablePressInt* and *enableTempHumidInt*, these flags will be used when testing interrupts, and a function *intHandler* that will be called when an interrupt is triggered.  The *intHandler* takes one parameter, the table received when reading the interrupts source register after interrupt occurs.

```
// Interrupt settings
local ENABLE_ACCEL_INT = true;
local ENABLE_PRESS_INT = false;
local ENABLE_TEMPHUMID_INT = false;

function interruptHandler(intTable) {
    if ("int1" in intTable) {
        imp.wakeup(0, function() {
            ledFeedback(true, "Freefall detected")
                .then(function(msg) {
                    server.log(msg);
                    return pause();
                }.bindenv(this))
                .then(function(msg) {
                    server.log(msg);
                    node.testLEDOn(SensorNodeTests.LED_GREEN);
                    node.testLEDOn(SensorNodeTests.LED_BLUE);
                    server.log("Testing Done.")
                }.bindenv(this))
        }.bindenv(this))
    }
}

// Initialize test class
node <- SensorNodeTests(ENABLE_ACCEL_INT, ENABLE_PRESS_INT, ENABLE_TEMPHUMID_INT, interruptHandler);
```

### Class Methods

#### scanSensorI2C()

Scans the onboard sensor i2c bus and logs addresses for the sensors it finds. Returns array of adresses.

```
node.scanSensorI2C();
```

#### scanRJ12I2C()

Scans the RJ45 i2c bus and logs addresses for the sensors it finds. Returns array of adresses.

```
node.scanRJ12I2C();
```

#### testSleep()

Boots at full power for 10s, then goes into a deep sleep for 20s.

```
node.testSleep();
```

#### testTempHumid()

Configures the sensor in one shot mode, takes a reading and logs the result. If humid reading between 0 & 100 and temperature reading is between 10 and 50 returns `true`.

```
node.testTempHumid();
```

#### testAccel()

Configures the sensor, gets a reading and logs the result.  If accel reading is between -1.5 and 1.5 on all axis returns `true`.

```
node.testAccel();
```

#### testPressure()

Configures the sensor in one shot mode, takes a reading and logs the result. If pressure reading is between 800 and 1200 returns `true`.

```
node.testPressure();
```


#### testOnewire();

Scans for Onewire bus for devices.  If devices are found logs the id for the device and returns `true`.  If no devices found returns `false`.

```
node.testOnewire();
```

#### testLEDOn(led)

Turns on the led passed in.

```
node.testLEDOn(SensorNodeTests.LED_GREEN);
```

#### testLEDOff(led)

Turns off the led passed in.

```
node.testLEDOff(SensorNodeTests.LED_BLUE);
```

### testInterrupts(*[testIntWakeUp]*)

Enables the interrupts based on the flags passed into the constructor. When an interrupt is detected it will be logged. Currently only the pressure and accelerometer interrupts are tested. If the boolean *testIntWakeUp* parameter is `true` the device is put to sleep and wakes when an interrupt is detected. The default value for *testIntWakeUp* is false.

```
local TEST_WAKE_INT = true;

node.testInterrupts(TEST_WAKE_INT);
```

## Basic Test Class

Test suite written to test Sensor Nodes.

### Class dependencies:

* Promise
* SensorNodeTests
    * HTS221
    * LPS22HB
    * LIS3DH
    * Onwire

### Class Usage

#### Constructor: BasicTest(*ledFeedbackTime, ledPauseTime*);

Initializes sensor node class, and sets up the test timing variables.

### Class Methods

#### run()

Runs tests all tests log results and turn on green LED if test passes, blue if test fails.

* test LEDs: turn on green led, then turn on blue led
* test temp/humid sensor reading in range
* test pressure sensor reading in range
* test accel reading in range
* test onwire device found
* test RJ12 i2c device found
* configures freefall interrupt and goes to sleep
* *MANUAL TEST* low power while alseep
* *MANUAL TEST* toss sensor node in air to wake
* test that freefall was triggered and sensor node wakes
* turns on both LEDs when all tests complete

##### Example:

```
local LED_FEEDBACK_AFTER_TEST = 2;
local PAUSE_BTWN_TESTS = 1.5;

test <- BasicTest(LED_FEEDBACK_AFTER_TEST, PAUSE_BTWN_TESTS);
test.run();
```
