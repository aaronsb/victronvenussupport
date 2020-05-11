# victronvenussupport
Support files for managing and deploying my Victron Venus OS stuff


@@ Quick Screen and Touch Setup Walkthrough - 4/17/2018 @@

ADAC and RTC are based on the Expander Pi: https://www.abelectronics.co.uk/p/50/Expander-Pi

16 channel digital signal: MCP23017
2 channel adac: MCP4822
8 channel analog to digital: MCP3208
DS1307 RTC Clock chip

###### Install Device Tree Binaries ######
 
touch screen overlay download:
https://github.com/kolargol/raspberry-minimal-kernel/raw/master/bins/4.1.8/overlays/rpi-ft5406-overlay.dtb

backlight overlay download:
https://github.com/PiNet/PiNet-Boot/raw/master/boot/overlays/rpi-backlight-overlay.dtb
Copy .dtb files into /u-boot/overlays/

ds1307 rtc overlay download:
https://github.com/PiNet/PiNet-Boot/raw/master/boot/overlays/ds1307-rtc-overlay.dtb

i2c-rtc overlay download:
https://github.com/PiNet/PiNet-Boot/raw/master/boot/overlays/i2c-rtc-overlay.dtb


######  Modify config.txt ######
Add  config lines to [all] section of /u-boot/config.txt (this is the config.txt variant that the venus os uses)
  
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
 
###### RTC Clock for DS1307 ######
#install kernel module package.
opkg install kernel-module-rtc-ds1307
#create /data/rc.local
#add this line to it to run on startup.
echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-1/new_device
hwclock -s
#end lines

#for reference
#hwclock -w
#write the system time to rtc

#hwclock -r
#reads it back from the rtc

#hwclock -s writes rtc back to system time

###### Add Venus configurables for backlight and display blanking ######
#Display brightness configurable
echo '/sys/class/backlight/rpi_backlight' >/etc/venus/backlight_device

#Display blanking configurable
echo '/sys/class/backlight/rpi_backlight/bl_power'  >/etc/venus/blank_display_device
 
 
 
###### Install modules and packages ######
 
opkg update
#Install QT4 mouse driver
opkg install qt4-embedded-plugin-mousedriver-tslib
#Install tslib stuff
opkg install tslib-calibrate
opkg install tslib-conf
opkg install tslib-tests
# install RPI kernel module for backlight
opkg install kernel-module-rpi-backlight

###### Create backlightctl.sh script (optional) ######
# This is an optional script to control backlight and dim it to a reasonable brightness when starting. You can insert it into /
# save this script in /opt/rpi-screen/backlightctl.sh
# chmod 755 the script (executable)
# symlink script: ln -s /usr/sbin/ /opt/rpi-screen/backlightctl.sh
#beginscript

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

# endscript





###### Calibrate touchscreen ######
# Set these variables temporarily to write the calibration file to the correct location.
TSLIB_FBDEVICE=/dev/fb0
TSLIB_TSDEVICE=/dev/input/touchscreen0
TSLIB_CALIBFILE=/etc/pointercal
TSLIB_CONFFILE=/etc/ts.conf
TSLIB_PLUGINDIR=/usr/lib/ts

# run tslib calibration and touchy the screen in the right spots.
ts_calibrate


###### Victron /opt/victronenergy/gui/start-gui.sh modification ######
#Add the following lines right after the  "when headfull "comment block
#Note that these require you to have calibrated the screen, saving the various calibration files.

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


###### USB GPS Device ######
opkg install gps-dbus
#after a reboot, usb gps device seemed to just magically work. "that was easy"


###### canable.io canbus interface setup ######
#requires slcand daemon to be installed.
#bought device from http://canable.io/
#device shows up  as a "CANtact" device 

#Create start and stop scripts for slcand

#/usr/local/bin/slcan_add.sh
#beginscript

#!/bin/sh
# Bind the USBCAN device
slcand -o -c -s5 /dev/serial/by-id/*CANtact* can0
ip link set can0 up

#endscript


#/usr/local/bin/slcan_remove.sh
#beginscript

#!/bin/sh
# Remove the USBCAN device
killall slcand

#endscript
#chmod 755 both scripts.
 
Add scripts to rules.d:
#create file /etc/udev/rules.d/slcan.rules
#add start and stop rules.
#note that the device is called "CANtact_dev"

ACTION=="add", ENV{ID_MODEL}=="CANtact_dev", ENV{SUBSYSTEM}=="tty", RUN+="/usr/bin/logger [udev] Canable CANUSB detected - running slcan_add.sh!", RUN+="/usr/local/bin/slcan_add.sh $kernel"
ACTION=="remove", ENV{ID_MODEL}=="CANtact_dev", ENV{SUBSYSTEM}=="usb", RUN+="/usr/bin/logger [udev] Canable CANUSB removed - running slcan_remove.sh!", RUN+="/usr/local/bin/slcan_remove.sh"

##end slcan.rules

##Pending testing, this should link the startup scripts for canbus functionality.
##https://groups.google.com/d/msg/victron-dev-venus/fnlzZlWCx58/uicAXiwwAwAJ

ln -s /opt/victronenergy/can-bus-bms/service /service/can-bus-bms.can0
ln -s /opt/victronenergy/dbus-motordrive/service /service/dbus-motordrive.can0
ln -s /opt/victronenergy/dbus-valence/service /service/dbus-valence.can0
ln -s /opt/victronenergy/vecan-dbus/service /service/vecan-dbus.can0
ln -s /opt/victronenergy/mqtt-n2k/service /service/mqtt-n2k.can0
#untested but probably just needs to be done once during setup.

###### Configure headless mode to disabled (enables the GUI on screen) ######
mv /etc/venus/headless /etc/venus/headless.off

reboot



###### Expander Pi ADAC Board ######
#https://www.abelectronics.co.uk/p/50/Expander-Pi
https://www.abelectronics.co.uk/p/50/Expander-Pi
#copy dtb to /u-boot/overlays
#excerpt from post:
#I had to convert the mcp3008-overlay.dtb to a dts file, change all references to 3008 to 3208, and convert it back to a dtb file, to get it to give me 12-bits (4095).
#(I've enclosed the dtb file if anyone needs it). The line in config.txt should read "dtoverlay=mcp3208:spi0-0-present"


#https://groups.google.com/d/msg/victron-dev-venus/mejgJbMjU34/WglmnUPQAwAJ

opkg install kernel-module-mcp320x
chmod 755 /opt/victronenergy/dbus-adc/start-adc.sh
chmod 755 /opt/victronenergy/dbus-adc/dbus-adc
chmod 755 /opt/victronenergy/dbus-adc/service/run
chmod 755 /opt/victronenergy/dbus-adc/log/run
touch /var/log/dbus-adc
ln -s /opt/victronenergy/dbus-adc/service /service/dbus-adc
#add to /u-boot/config.txt
#you did this way at the top.


https://groups.google.com/d/msg/victron-dev-venus/mejgJbMjU34/1Pu-vHtvAwAJ



###### GPIO Pins for Opto protected relay coltrol ######
https://groups.google.com/d/msg/victron-dev-venus/nqkpANtRCBU/IeDx5lbfAAAJ

