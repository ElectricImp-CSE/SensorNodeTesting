// Temp/Humid Sensor Lib
#require "HTS221.class.nut:1.0.1"
// Air Pressure Sensor Lib
#require "LPS22HB.class.nut:1.0.0"
// Accelerometer Sensor Lib
#require "LIS3DH.class.nut:1.3.0"
// OneWire Lib
#require "Onewire.class.nut:1.0.1"
// Promise Lib
#require "promise.class.nut:3.0.0"

SensorNode_003 <- {
    "LED_BLUE" : hardware.pinP,
    "LED_GREEN" : hardware.pinU,
    "SENSOR_I2C" : hardware.i2cAB,
    "TEMP_HUMID_I2C_ADDR" : 0xBE,
    "ACCEL_I2C_ADDR" : 0x32,
    "PRESSURE_I2C_ADDR" : 0xB8,
    "RJ12_ENABLE_PIN" : hardware.pinS,
    "ONEWIRE_BUS_UART" : hardware.uartDM,
    "RJ12_I2C" : hardware.i2cFG,
    "RJ12_UART" : hardware.uartFG,
    "WAKE_PIN" : hardware.pinW,
    "ACCEL_INT_PIN" : hardware.pinT,
    "PRESSURE_INT_PIN" : hardware.pinX,
    "TEMP_HUMID_INT_PIN" : hardware.pinE,
    "NTC_ENABLE_PIN" : hardware.pinK,
    "THERMISTER_PIN" : hardware.pinJ,
    "FTDI_UART" : hardware.uartQRPW,
    "PWR_3v3_EN" : hardware.pinY
}

class SensorNodeTests {
    static LED_GREEN = SensorNode_003.LED_GREEN;
    static LED_BLUE = SensorNode_003.LED_BLUE;
    static LED_ON = 0;
    static LED_OFF = 1;

    _enableAccelInt = null;
    _enablePressInt = null;
    _enableTempHumidInt = null;

    _intHandler = null;

    _wake = null;

    tempHumid = null;
    press = null;
    accel = null;

    ow = null;

    led_blue = null;
    led_green = null;

    testDone = false;

    constructor(enableAccelInt, enablePressInt, enableTempHumidInt, intHandler) {

        imp.enableblinkup(true);
        _enableAccelInt = enableAccelInt;
        _enablePressInt = enablePressInt;
        _enableTempHumidInt = enableTempHumidInt;

        _intHandler = intHandler;

        _wake = SensorNode_003.WAKE_PIN;

        SensorNode_003.SENSOR_I2C.configure(CLOCK_SPEED_400_KHZ);
        SensorNode_003.RJ12_I2C.configure(CLOCK_SPEED_400_KHZ);

        // initialize sensors
        tempHumid = HTS221(SensorNode_003.SENSOR_I2C, SensorNode_003.TEMP_HUMID_I2C_ADDR);
        press = LPS22HB(SensorNode_003.SENSOR_I2C, SensorNode_003.PRESSURE_I2C_ADDR);
        accel = LIS3DH(SensorNode_003.SENSOR_I2C, SensorNode_003.ACCEL_I2C_ADDR);
        ow = Onewire(SensorNode_003.ONEWIRE_BUS_UART, true);

        // configure leds
        LED_GREEN.configure(DIGITAL_OUT, LED_OFF);
        LED_BLUE.configure(DIGITAL_OUT, LED_OFF);

        _checkWakeReason();
    }

    function scanSensorI2C() {
        local addrs = [];
        for (local i = 2 ; i < 256 ; i+=2) {
            if (SensorNode_003.SENSOR_I2C.read(i, "", 1) != null) {
                server.log(format("Device at address: 0x%02X", i));
                addrs.push(i);
            }
        }
        return addrs;
    }

    function scanRJ12I2C() {
        SensorNode_003.PWR_3v3_EN.configure(DIGITAL_OUT, 1);
        local addrs = [];
        SensorNode_003.RJ12_ENABLE_PIN.configure(DIGITAL_OUT, 1);
        for (local i = 2 ; i < 256 ; i+=2) {
            if (SensorNode_003.RJ12_I2C.read(i, "", 1) != null) {
                server.log(format("Device at address: 0x%02X", i));
                addrs.push(i);
            }
        }
        SensorNode_003.PWR_3v3_EN.write(0);
        return addrs;
    }

    function testSleep() {
        server.log("At full power...");
        imp.wakeup(10, function() {
            server.log("Going to deep sleep for 20s...");
            accel.enable(false);
            imp.onidle(function() { imp.deepsleepfor(20); })
        }.bindenv(this))
    }

    function testTempHumid() {
        // Take a sync reading and log it
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        local thReading = tempHumid.read();
        if ("error" in thReading) {
            server.error(thReading.error);
            return false;
        } else {
            server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", thReading.humidity, "%", thReading.temperature));
            return ((thReading.humidity > 0 && thReading.humidity < 100) && (thReading.temperature > 10 && thReading.temperature < 50));
        }
    }

    function testAccel() {
        // Take a sync reading and log it
        accel.init();
        accel.setDataRate(10);
        accel.enable();
        local accelReading = accel.getAccel();
        server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));
        return (accelReading.x > -1.5 && accelReading.x < 1.5) && (accelReading.y > -1.5 && accelReading.y < 1.5) && (accelReading.z > -1.5 && accelReading.z < 1.5)
    }

    function testPressure() {
        // Take a sync reading and log it
        press.softReset();
        local pressReading = press.read();
        if ("error" in pressReading) {
            server.error(pressReading.error);
            return false;
        } else {
            server.log("Current Pressure: " + pressReading.pressure);
            return (pressReading.pressure > 800 && pressReading.pressure < 1200);
        }
    }

    function testOnewire() {
        SensorNode_003.PWR_3v3_EN.configure(DIGITAL_OUT, 1);
        if (ow.reset()) {
            local devices = ow.discoverDevices();
            foreach (id in devices) {
                local str = ""
                foreach(idx, val in id) {
                    str += val
                    if (idx < id.len()) str += "."
                }
                server.log("Found device with id: " + str);
            }
            return (devices.len() > 0);
        }
        SensorNode_003.PWR_3v3_EN.write(0);
        return false;
    }

    function testLEDOn(led) {
        led.configure(DIGITAL_OUT, LED_ON);
        // server.log("Turning LED ON")
    }

    function testLEDOff(led) {
        led.write(LED_OFF);
        // server.log("Turning LED OFF")
    }

    function testInterrupts(testWake = false) {
        clearInterrupts();

        // Configure interrupt pins
        _wake.configure(DIGITAL_IN_WAKEUP, function() {
            // When awake only trigger on pin high
            if (!testWake && _wake.read() == 0) return;

            local accelReading = accel.getAccel();
            server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));

            // Determine interrupt
            if (_enableAccelInt) _accelIntHandler();
            if (_enablePressInt) _pressIntHandler();

        }.bindenv(this));

        if (_enableAccelInt) _enableAccelInterrupt();
        if (_enablePressInt) _enablePressInterrupt();

        if (testWake) {
            _sleep();
        }
    }

    function logIntPinState() {
        server.log("Wake pin: " + _wake.read());
        server.log("Accel int pin: " + SensorNode_003.ACCEL_INT_PIN.read());
        server.log("Press int pin: " + SensorNode_003.PRESSURE_INT_PIN.read());
    }

    // Private functions/Interrupt helpers
    // -------------------------------------------------------

    function _checkWakeReason() {
        local wakeReason = hardware.wakereason();
        switch (wakeReason) {
            case WAKEREASON_PIN:
                // Woke on interrupt pin
                server.log("Woke b/c int pin triggered");
                testDone = true;
                if (_enableAccelInt) _accelIntHandler();
                if (_enablePressInt) _pressIntHandler();
                break;
            case WAKEREASON_TIMER:
                // Woke on timer
                server.log("Woke b/c timer expired");
                break;
            default :
                // Everything else
                server.log("Rebooting...");
        }
    }

    function _sleep() {
        if (_wake.read() == 1) {
            // logIntPinState();
            imp.wakeup(1, _sleep.bindenv(this));
        } else {
            // sleep for 24h
            imp.onidle(function() { server.sleepfor(86400); });
        }
    }

    function clearInterrupts() {
        accel.configureFreeFallInterrupt(false);
        press.configureThresholdInterrupt(false);
        accel.getInterruptTable();
        press.getInterruptSrc();
        // logIntPinState();
    }

    function _enableAccelInterrupt() {
        accel.setDataRate(100);
        accel.enable();
        accel.configureInterruptLatching(true);
        accel.getInterruptTable();
        accel.configureFreeFallInterrupt(true);
        server.log("Free fall interrupt configured...");
        // accel.configureClickInterrupt(true, LIS3DH.DOUBLE_CLICK, 1.5, 5, 10, 50);
        // server.log("Double Click interrupt configured...");
    }

    function _accelIntHandler() {
        local intTable = accel.getInterruptTable();
        if (intTable.int1) server.log("Free fall detected: " + intTable.int1);
        // if (intTable.click) server.log("Click detected: " + intTable.click);
        // if (intTable.singleClick) server.log("Single click detected: " + intTable.singleClick);
        // if (intTable.doubleClick) server.log("Double click detected: " + intTable.doubleClick);
        _intHandler(intTable);
    }

    function _enablePressInterrupt() {
        press.setMode(LPS22HB_MODE.CONTINUOUS, 25);
        local intTable = press.getInterruptSrc();
        // this should always fire...
        press.configureThresholdInterrupt(true, 1000, LPS22HB.INT_LATCH | LPS22HB.INT_HIGH_PRESSURE);
        server.log("Pressure interrupt configured...");
    }

    function _pressIntHandler() {
        local intTable = press.getInterruptSrc();
        if (intTable.int_active) {
            server.log("Pressure int triggered: " + intTable.int_active);
            if (intTable.high_pressure) server.log("High pressure int: " + intTable.high_pressure);
            if (intTable.low_pressure) server.log("Low pressure int: " + intTable.low_pressure);
        }
        _intHandler(intTable);
    }

}

// SETUP
// ------------------------------------------

class BasicTest {

    // Interrupt settings
    static TEST_WAKE_INT = true;
    static ENABLE_ACCEL_INT = true;
    static ENABLE_PRESS_INT = false;
    static ENABLE_TEMPHUMID_INT = false;

    feedbackTimer = null;
    pauseTimer = null;
    node = null;

    constructor(_feedbackTimer, _pauseTimer) {
        feedbackTimer = _feedbackTimer;
        pauseTimer = _pauseTimer;
        node = SensorNodeTests(ENABLE_ACCEL_INT, ENABLE_PRESS_INT, ENABLE_TEMPHUMID_INT, interruptHandler.bindenv(this));
    }

    function run() {
        if (!node.testDone) {
            testLEDs()
                .then(function(msg) {
                    server.log(msg);
                    return pause();
                }.bindenv(this))
                // Temp humid sensor test
                .then(function(msg) {
                    server.log(msg);
                    return ledFeedback(node.testTempHumid(), "Temp Humid sensor reading");
                }.bindenv(this))
                .then(function(msg) {
                    server.log(msg);
                    return pause();
                }.bindenv(this))
                // Pressure sensor test
                .then(function(msg) {
                    server.log(msg);
                    return ledFeedback(node.testPressure(), "Pressure sensor reading");
                }.bindenv(this))
                .then(function(msg) {
                    server.log(msg);
                    return pause();
                }.bindenv(this))
                // Accel sensor test
                .then(function(msg) {
                    server.log(msg);
                    return ledFeedback(node.testAccel(), "Accel sensor reading");
                }.bindenv(this))
                .then(function(msg) {
                    server.log(msg);
                    return pause();
                }.bindenv(this))
                // Onwire discovery test
                .then(function(msg) {
                    server.log(msg);
                    return ledFeedback(node.testOnewire(), "OneWire discovery");
                }.bindenv(this))
                .then(function(msg) {
                    server.log(msg);
                    return pause();
                }.bindenv(this))
                // Onewire i2c test
                .then(function(msg) {
                    server.log(msg);
                    local sensors = node.scanRJ12I2C();
                    return ledFeedback(sensors.find(0x80) != null, "OneWire I2C scan");
                }.bindenv(this))
                .then(function(msg) {
                    server.log(msg);
                    return pause();
                }.bindenv(this))
                .then(function(msg) {
                    server.log(msg);
                    server.log("Test low power. Then wake by tossing");
                    // configure interrupt, and sleep
                    node.testInterrupts(TEST_WAKE_INT)
                }.bindenv(this))
        }
    }

    function pause() {
        return Promise(function(resolve, reject) {
            imp.wakeup(pauseTimer, function() {
                return resolve("Starting next test...")
            });
        }.bindenv(this))
    }

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

    function testLEDs() {
        return Promise(function(resolve, reject) {
            // Green LED on
            node.testLEDOn(SensorNodeTests.LED_GREEN);
            imp.wakeup(feedbackTimer, function() {
                // Green LED off
                node.testLEDOff(SensorNodeTests.LED_GREEN);
                imp.wakeup(pauseTimer, function() {
                    // Blue LED on
                    node.testLEDOn(SensorNodeTests.LED_BLUE);
                    imp.wakeup(feedbackTimer, function() {
                        // Blue led off
                        node.testLEDOff(SensorNodeTests.LED_BLUE);
                        return resolve("LED Tesing Passed");
                    }.bindenv(this));
                }.bindenv(this))
            }.bindenv(this));
        }.bindenv(this))
    }

    function ledFeedback(testResult, sensorMsg) {
        return Promise(function (resolve, reject) {
            local resultMsg;
            if (testResult) {
                // Green LED on
                node.testLEDOn(SensorNodeTests.LED_GREEN);
                resultMsg = " test passed";
            } else {
                // Blue LED on
                node.testLEDOn(SensorNodeTests.LED_BLUE);
                resultMsg = " TEST FAILED!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
            }
            imp.wakeup(feedbackTimer, function() {
                node.testLEDOff(SensorNodeTests.LED_GREEN);
                node.testLEDOff(SensorNodeTests.LED_BLUE);
                return resolve(sensorMsg + resultMsg);
            }.bindenv(this));
        }.bindenv(this));
    }
}


// // RUN TESTS
// // ------------------------------------------
server.log("device running...");

local LED_FEEDBACK_AFTER_TEST = 2;
local PAUSE_BTWN_TESTS = 1.5;

test <- BasicTest(LED_FEEDBACK_AFTER_TEST, PAUSE_BTWN_TESTS);
test.run();
