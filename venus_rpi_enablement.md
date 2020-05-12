# Victron Venus On Raspberry PI
Support files for managing and deploying my Victron Venus OS stuff
Please issue a pull request with updated urls to links and stuff if you've found they're out of date and I'll integrate them in.

* ADAC and RTC are based on the Expander Pi: https://www.abelectronics.co.uk/p/50/Expander-Pi
* 16 channel digital signal: MCP23017
* 2 channel adac: MCP4822
* 8 channel analog to digital: MCP3208
* DS1307 RTC Clock chip

### Install Device Tree Binaries ###
 
* touch screen overlay download: https://github.com/kolargol/raspberry-minimal-kernel/raw/master/bins/4.1.8/overlays/rpi-ft5406-overlay.dtb
* backlight overlay download: https://github.com/PiNet/PiNet-Boot/raw/master/boot/overlays/rpi-backlight-overlay.dtb
* Copy .dtb files into /u-boot/overlays/
* ds1307 rtc overlay download: https://github.com/PiNet/PiNet-Boot/raw/master/boot/overlays/ds1307-rtc-overlay.dtb
* i2c-rtc overlay download: https://github.com/PiNet/PiNet-Boot/raw/master/boot/overlays/i2c-rtc-overlay.dtb


###  Modify config.txt ###
Add config lines to [all] section of `/u-boot/config.txt` (this is the config.txt variant that the venus os uses)

/u-boot/config.txt
```bash  
#turn on SPI interface
dtparam=spi=on

#turn on i2c_arm bus
dtparam=i2c_arm=on

#turn on i2s bus
dtparam=i2s=on

#set framebuffer pixles wide to 480
framebuffer_width=480

#set framebuffer pixles high to 272. Lower resolution than native but allows scaling of the CCGX UI to full screen, and causes touch to work correctly.
framebuffer_height=272

#lcd was upside down on my device, setting this configures both touch and lcd to orient correctly.
lcd_rotate=2

#dtoverlays - MCP3208 ADAC on spi-0-0, i2c rtc interface, and ds1307 rtc interface. (that lives on the i2c bus)
dtoverlay=mcp3208:spi0-0-present,i2c-rtc,ds1307-rtc
```

### RTC Clock for DS1307 ###
Install kernel module package.
```bash
opkg install kernel-module-rtc-ds1307
```
Create a file called /data/rc.local add this line to it to run on startup.

/data/rc.local
```bash
echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-1/new_device
hwclock -s
```

This command updates the current system time to RTC.
```bash
hwclock -w
```

This command just displays the RTC clock time.
```bash
hwclock -r
```
This commands writes time from RTC to the system time.
```bash
hwclock -s writes rtc back to system time
```

### Add Venus configurables for backlight and display blanking ###

This is a display brightness configurable
```bash
echo '/sys/class/backlight/rpi_backlight' >/etc/venus/backlight_device
```

Display blanking configurable
```bash
echo '/sys/class/backlight/rpi_backlight/bl_power'  >/etc/venus/blank_display_device
``` 
 
 
### Install modules and packages ###

Update packages to latest first.
```bash
opkg update
```
Install QT4 mouse driver
```bash
opkg install qt4-embedded-plugin-mousedriver-tslib
```
Install tslib (touchscreen) stuff
```bash
opkg install tslib-calibrate
opkg install tslib-conf
opkg install tslib-tests
```
Install RPI kernel module for backlight
```bash
opkg install kernel-module-rpi-backlight
```
### Create backlightctl.sh script (optional) ###

This is an optional script to control backlight and dim it to a reasonable brightness when starting. You can insert it into/save this script in `/opt/rpi-screen/backlightctl.sh`

After creating the file, set the script to set it executable, then symlink script.

/opt/rpi-screen/backlightctl.sh
```bash
chmod 755 /opt/rpi-screen/backlightctl.sh
ln -s /usr/sbin/ /opt/rpi-screen/backlightctl.sh
```

```bash
#!/bin/bash

b="$(cat /sys/class/backlight/rpi_backlight/actual_brightness)"
p="$(cat /sys/class/backlight/rpi_backlight/bl_power)"
if [ $# != 1 ]
  then
    echo "Use integer [1-255] to control backlight intensity."
    echo "Use 0 to turn off backlight."
    echo "Backlight intensity is set to $b."
    if [ $p = 1 ]
     then
      echo "Backlight is not energised."
     else
      echo "Backlight is energised."
    fi
    exit 1
  fi

if [ $1 -eq 0 ]
 then
   echo "Turning off backlight"
   echo 1 > /sys/class/backlight/rpi_backlight/bl_power
exit 0
fi

if [[ $1 -ge 1 && $1 -le 255 ]]
 then
   echo "Turning on backlight"
   echo 0 > /sys/class/backlight/rpi_backlight/bl_power
   echo "Setting backlight to $1"
   echo $1 > /sys/class/backlight/rpi_backlight/brightness
 else
   echo "Backlight level out of range"
 exit 1
fi
```

### Calibrate touchscreen ###
Set these variables temporarily to write the calibration file to the correct location.
```bash
TSLIB_FBDEVICE=/dev/fb0
TSLIB_TSDEVICE=/dev/input/touchscreen0
TSLIB_CALIBFILE=/etc/pointercal
TSLIB_CONFFILE=/etc/ts.conf
TSLIB_PLUGINDIR=/usr/lib/ts
```
Run tslib calibration and touchy the screen in the right spots.

```bash
ts_calibrate
```

### Victron /opt/victronenergy/gui/start-gui.sh modification ###
Add the following lines right after the  `"when headfull "` comment block.
Note that these require you to have first calibrated the screen, saving the various calibration files. backlightctl.sh is listed just above. If you didn't want to use it, omit that from your modification.

/opt/victronenergy/gui/start-gui.sh
```bash
export TSLIB_TSEVENTTYPE=INPUT
export TSLIB_CONSOLEDEVICE=none
export TSLIB_FBDEVICE=/dev/fb0
export TSLIB_TSDEVICE=/dev/input/touchscreen0
export TSLIB_CALIBFILE=/etc/pointercal
export TSLIB_CONFFILE=/etc/ts.conf
export TSLIB_PLUGINDIR=/usr/lib/ts
export QWS_MOUSE_PROTO=tslib:/dev/input/touchscreen0
echo "*** Setting backlight intensity to 50 ***"
backlightctl.sh 50
```

### USB GPS Device ###

After a reboot, usb gps device seemed to just magically work. "that was easy"
```bash
opkg install gps-dbus
```


### canable.io canbus interface setup ###
This requires slcand daemon to be installed.
I bought this device from http://canable.io/, and it shows up as a "CANtact" device 

Create start and stop scripts for slcand. You'll need an add and remove script.

/usr/local/bin/slcan_add.sh
```bash
#!/bin/sh

### Bind the USBCAN device
slcand -o -c -s5 /dev/serial/by-id/*CANtact* can0
ip link set can0 up
```
/usr/local/bin/slcan_remove.sh
```bash
#beginscript

#!/bin/sh

### Remove the USBCAN device
killall slcand
```

Make sure you chmod 755 (executable) both scripts.
 
Add scripts to rules.d so it works for starting and stopping properly.

Create file `/etc/udev/rules.d/slcan.rules`, which adds start and stop rules. Note that the device is called "CANtact_dev" - if you have a different device it might show up as a differently named device.

/etc/udev/rules.d/slcan.rules
```bash
ACTION=="add", ENV{ID_MODEL}=="CANtact_dev", ENV{SUBSYSTEM}=="tty", RUN+="/usr/bin/logger [udev] Canable CANUSB detected - running slcan_add.sh!", RUN+="/usr/local/bin/slcan_add.sh $kernel"
ACTION=="remove", ENV{ID_MODEL}=="CANtact_dev", ENV{SUBSYSTEM}=="usb", RUN+="/usr/bin/logger [udev] Canable CANUSB removed - running slcan_remove.sh!", RUN+="/usr/local/bin/slcan_remove.sh"
```



###Link the startup scripts for CANbus functionality.

See https://groups.google.com/d/msg/victron-dev-venus/fnlzZlWCx58/uicAXiwwAwAJ that post for more details on how this came to be.

```bash
ln -s /opt/victronenergy/can-bus-bms/service /service/can-bus-bms.can0
ln -s /opt/victronenergy/dbus-motordrive/service /service/dbus-motordrive.can0
ln -s /opt/victronenergy/dbus-valence/service /service/dbus-valence.can0
ln -s /opt/victronenergy/vecan-dbus/service /service/vecan-dbus.can0
ln -s /opt/victronenergy/mqtt-n2k/service /service/mqtt-n2k.can0
```

For my purposes, I needed to set the CANbus device to a speed of 250k for my BMS to talk to it properly 

### Configure headless mode to disabled (enables the GUI on screen) ###
You need to reboot for this setting to take effect.
```bash
mv /etc/venus/headless /etc/venus/headless.off
sudo reboot now
```


### Expander Pi ADAC Board ###
I got the Epander PI from here https://www.abelectronics.co.uk/p/50/Expander-Pi

The trick to making this work since it's an SPI device that needs to identify as an PCM 3208, the DTB had to be modified to properly discover it. Just copy the DTB file over from here https://github.com/aaronsb/victronvenussupport/blob/master/mcp3208-overlay.dtb and save into /u-boot/overlays on the RPI.

Here's an excerpt from post: (https://groups.google.com/d/msg/victron-dev-venus/mejgJbMjU34/WglmnUPQAwAJ)

>I had to convert the mcp3008-overlay.dtb to a dts file, change all references to 3008 to 3208, and convert it back to a dtb file, to get it to give me 12-bits (4095).
>(I've enclosed the dtb file if anyone needs it). The line in config.txt should read "dtoverlay=mcp3208:spi0-0-present"

After adding that file to `/u-boot/config.txt`, install the kernel driver and set the following items executable, and link the service to the right dbus node.

```bash
opkg install kernel-module-mcp320x
chmod 755 /opt/victronenergy/dbus-adc/start-adc.sh
chmod 755 /opt/victronenergy/dbus-adc/dbus-adc
chmod 755 /opt/victronenergy/dbus-adc/service/run
chmod 755 /opt/victronenergy/dbus-adc/log/run
touch /var/log/dbus-adc
ln -s /opt/victronenergy/dbus-adc/service /service/dbus-adc
```

### GPIO Pins for Opto protected relay coltrol ###

The original post is located here https://groups.google.com/d/msg/victron-dev-venus/nqkpANtRCBU/IeDx5lbfAAAJ I've included it for sake of completion.


1. First off, pick a suitable GPIO. It seems to me the obvious choices would be something that is not multiplexed onto another function (some pins do double duty and can be configured to be something else), so the obvious choice to me seems to be GPIO21, which is on pin 40 on the header (right at the end). What's nice about this one, is it has a ground right next to it on pin 39.

2. Next you have configure this pin as a gpio. There is some functionality built into venus to do this, but not yet enabled on the Pi, so you will have to manually install this. First create /etc/venus/gpio_list by using the following command:
```bash
echo "21  out relay_1" > /etc/venus/gpio_list
```

3. Install the setup script and make it executable, like so:
```bash
wget -O /etc/init.d/gpio_pins.sh https://raw.githubusercontent.com/victronenergy/meta-victronenergy/master/meta-venus/recipes-bsp/gpio-export/files/gpio_pins.sh
chmod +x /etc/init.d/gpio_pins.sh
```

4. Create a symlink to make gpio setup run at boot:
```bash
cd /etc/rcS.d
ln -s ../init.d/gpio_pins.sh /etc/rcS.d/S90gpio_pins.sh
```

5. Either reboot, or just run the script manually to set up the gpios at this time (you will reboot again later):
```bash
/etc/init.d/gpio_pins.sh
```

6. You should now have a file /dev/gpio/relay_1 configured as an output.

7. Create /etc/venus/relays and add the relevant gpio
```bash
echo /sys/class/gpio/gpio21 > /etc/venus/relays
```

8. Reboot. The relay should now show up in the list.
