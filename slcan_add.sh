#!/bin/sh

### Bind the USBCAN device
slcand -o -c -s5 /dev/serial/by-id/*CANtact* can0
ip link set can0 up
