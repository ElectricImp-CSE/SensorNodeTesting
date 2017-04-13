// Temp/Humid Sensor Lib
#require "HTS221.class.nut:1.0.1"
// Air Pressure Sensor Lib
#require "LPS22HB.class.nut:1.0.0"
// Accelerometer Sensor Lib
#require "LIS3DH.class.nut:1.3.0"
// OneWire Lib
#require "Onewire.class.nut:1.0.1"

SensorNode_003 <- {
    "LED_BLUE" : hardware.pinP,
    "LED_GREEN" : hardware.pinU,
    "SENSOR_I2C" : hardware.i2cAB,
    "TEMP_HUMID_I2C_ADDR" : 0xBE,
    "ACCEL_I2C_ADDR" : 0x32,
    "PRESSURE_I2C_ADDR" : 0xB8,
    "RJ45_ENABLE_PIN" : hardware.pinS,
    "ONEWIRE_BUS_UART" : hardware.uartDM,
    "RJ45_I2C" : hardware.i2cFG,
    "RJ45_UART" : hardware.uartFG,
    "WAKE_PIN" : hardware.pinW,
    "ACCEL_INT_PIN" : hardware.pinT,
    "PRESSURE_INT_PIN" : hardware.pinX,
    "TEMP_HUMID_INT_PIN" : hardware.pinE,
    "NTC_ENABLE_PIN" : hardware.pinK,
    "THERMISTER_PIN" : hardware.pinJ,
    "FTDI_UART" : hardware.uartQRPW
}

class SensorNodeTest {
    static LED_ON = 0;
    static LED_OFF = 1;

    _enableAccelInt = null;
    _enablePressInt = null;
    _enableTempHumidInt = null;

    _wake = null;

    tempHumid = null;
    press = null;
    accel = null;

    ow = null;

    led_blue = null;
    led_green = null;


    constructor(enableAccelInt, enablePressInt, enableTempHumidInt) {

        imp.enableblinkup(true);
        _enableAccelInt = enableAccelInt;
        _enablePressInt = enablePressInt;
        _enableTempHumidInt = enableTempHumidInt;

        _wake = SensorNode_003.WAKE_PIN;

        SensorNode_003.SENSOR_I2C.configure(CLOCK_SPEED_400_KHZ);
        SensorNode_003.RJ45_I2C.configure(CLOCK_SPEED_400_KHZ);

        // initialize sensors
        tempHumid = HTS221(SensorNode_003.SENSOR_I2C, SensorNode_003.TEMP_HUMID_I2C_ADDR);
        press = LPS22HB(SensorNode_003.SENSOR_I2C, SensorNode_003.PRESSURE_I2C_ADDR);
        accel = LIS3DH(SensorNode_003.SENSOR_I2C, SensorNode_003.ACCEL_I2C_ADDR);
        ow = Onewire(SensorNode_003.ONEWIRE_BUS_UART, true);

        _checkWakeReason();
    }

    function scanSensorI2C() {
        for (local i = 2 ; i < 256 ; i+=2) {
            if (SensorNode_003.SENSOR_I2C.read(i, "", 1) != null) server.log(format("Device at address: 0x%02X", i));
        }
    }

    function scanRJ45I2C() {
        SensorNode_003.RJ45_ENABLE_PIN.configure(DIGITAL_OUT, 1);
        for (local i = 2 ; i < 256 ; i+=2) {
            if (SensorNode_003.RJ45_I2C.read(i, "", 1) != null) server.log(format("Device at address: 0x%02X", i));
        }
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
        if ("error" in thReading) server.error(thReading.error);
        server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", thReading.humidity, "%", thReading.temperature));
    }

    function testAccel() {
        // Take a sync reading and log it
        accel.init();
        accel.setDataRate(10);
        accel.enable();
        local accelReading = accel.getAccel();
        server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));
    }

    function testPressure() {
        // Take a sync reading and log it
        press.softReset();
        local pressReading = press.read();
        server.log(pressReading.pressure);
        server.log(format("Current Pressure: %0.2f in Hg", (1.0 * pressReading.pressure)/33.8638866667));
    }

    function testOnewire() {
        if (ow.reset()) {
            local devices = ow.discoverDevices();
            foreach (id in devices) {
                server.log("Found device with id: " + id);
            }
        }
    }

    function testLEDs() {
        local blue = SensorNode_003.LED_BLUE;
        local green = SensorNode_003.LED_GREEN;

        server.log("Turning blue LED on");
        blue.configure(DIGITAL_OUT, LED_ON);

        imp.wakeup(5, function() {
            server.log("Turning green LED on");
            green.configure(DIGITAL_OUT, LED_ON);
        }.bindenv(this))

        imp.wakeup(20, function() {
            server.log("Turning LEDs off");
            blue.write(LED_OFF);
            green.write(LED_OFF);
        }.bindenv(this));
    }

    function testInterrupts(testWake = false) {
        clearInterrupts();

        // Configure interrupt pins
        _wake.configure(DIGITAL_IN_WAKEUP, function() {
            // When awake only trigger on pin high
            if (!testWake && _wake.read() == 0) return;

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
            logIntPinState();
            imp.wakeup(1, _sleep.bindenv(this));
        } else {
            imp.onidle(function() { server.sleepfor(300); });
        }
    }

    function clearInterrupts() {
        accel.configureFreeFallInterrupt(false);
        press.configureThresholdInterrupt(false);
        accel.getInterruptTable();
        press.getInterruptSrc();
        logIntPinState();
    }

    function _enableAccelInterrupt() {
        accel.setDataRate(100);
        accel.enable();
        accel.configureInterruptLatching(true);
        accel.getInterruptTable();
        accel.configureFreeFallInterrupt(true);
        server.log("Free fall interrupt configured...");
    }

    function _accelIntHandler() {
        local intTable = accel.getInterruptTable();
        if (intTable.int1) server.log("Free fall detected: " + intTable.int1);
    }

    function _enablePressInterrupt() {
        press.setMode(LPS22HB_MODE.CONTINUOUS, 25);
        local intTable = press.getInterruptSrc();
        press.configureThresholdInterrupt(true, 1000, LPS22HB.INT_LATCH | LPS22HB.INT_LOW_PRESSURE | LPS22HB.INT_HIGH_PRESSURE);
        server.log("Pressure interrupt configured...");
    }

    function _pressIntHandler() {
        local intTable = press.getInterruptSrc();
        if (intTable.int_active) {
            server.log("Pressure int triggered: " + intTable.int_active);
            if (intTable.high_pressure) server.log("High pressure int: " + intTable.high_pressure);
            if (intTable.low_pressure) server.log("Low pressure int: " + intTable.low_pressure);
        }
    }

}


// SETUP
// ------------------------------------------

// Interrupt settings
local TEST_WAKE_INT = true;
local ENABLE_ACCEL_INT = true;
local ENABLE_PRESS_INT = false;
local ENABLE_TEMPHUMID_INT = false;

// Initialize test class
node <- SensorNodeTest(ENABLE_ACCEL_INT, ENABLE_PRESS_INT, ENABLE_TEMPHUMID_INT);

// // RUN TESTS
// // ------------------------------------------

// // Scan for the sensor addresses
// node.scanSensorI2C();

// // Test that all sensors can take a reading,
// // and that LED truns on and off (via library calls or toggling power gate)
// node.testTempHumid();
// node.testAccel();
// node.testPressure();
// node.testLEDs();

// // Test Interrupt
// node.testInterrupts(TEST_WAKE_INT);