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
