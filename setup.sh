#! /bin/bash

################################################################################
##                                                                            ##
## This will set up a Pi3 with Ubuntu 20.04 for use with the BrickPi3 and C++ ##
##                                                                            ##
## * Sets up the SPI                                                          ##
## * Sets up I2C for use with the Grove port if desired                       ##
## * Installs required libraries such as wiringpi                             ##
## * Draws on raspi-config and the Dexter Industries BrickPi3 setup scripts   ##
##                                                                            ##
## https://archive.raspberrypi.org/debian/pool/main/r/raspi-config/           ##
## https://github.com/DexterInd/BrickPi3                                      ##
##                                                                            ##
################################################################################

################################################################################
# Constants

BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt
MODULES=/etc/modules

TMP=/tmp/BrickPi3
SHARED_LIB=libbrickpi.so
STATIC_LIB=libbrickpi.a
LIB=/usr/lib
INCLUDE=/usr/include

################################################################################
# Initial setup

# Some of the commands we will use require elevated privileges
if [ $(id -u) -ne 0 ]; then
    echo "Script must be run with sudo"
    exit 1
fi

# Update the system
sudo apt update && sudo apt upgrade -y

# Install additional libraries
# Python shouldn't be needed
sudo apt install -y git build-essential libffi-dev libraspberrypi-bin \
                     libi2c-dev i2c-tools wiringpi openocd # python3-dev\
                     #python3-setuptools python3-pip python-is-python3

################################################################################
# SPI and I2C

echo "Setting up SPI"

# Enable SPI
# This is modified from raspi-config
if ! grep -q -E "dtparam=spi[= ]on" $CONFIG; then
    echo "dtparam=spi on" > $CONFIG
elif grep -q -E "(#+)dtparam=spi[= ]on" $CONFIG; then
    sed $CONFIG -i -e "s/#+\(dtparam=spi[= ]on\)/\1/"
elif grep -q -E "dtparam=spi[= ]off" $CONFIG; then
    sed $CONFIG -i -e "s/\(dtparam=spi[= ]\)off/\1on/"
else
    ### TODO: Automate ###
    # raspi-config uses lua for this...
    echo "Existing SPI setting found in " $CONFIG
    echo "Currently this will need manually setting"
fi

if ! grep -q "^(#)*( )*spi-dev" $MODULES; then
    echo "i2c-dev" >> $MODULES
else
    sed $MODULES -i -e "S/^#[[:space:]]*\(spi-dev\)/\1"
fi

if ! [ -e $BLACKLIST ]; then
    touch $BLACKLIST
else
    # This should never happen as it's not a part of Ubuntu, but hey, just in 
    # case
    sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*spi[-_]bcm2708\)/\1/"
fi

dtparam spi=on

# Enable I2C
echo "Setting up I2C"

if ! grep -q -E "dtparam=i2c(_arm)?[= ]on" $CONFIG; then
    echo "dtparam=i2c_arm on" > $CONFIG
elif grep -q -E "(#+)dtparam=i2c(_arm)?[= ]on" $CONFIG; then
    sed $CONFIG -i -e "s/#+\(dtparam=i2c\(_arm\)?[= ]on\)/\1/"
elif grep -q -E "dtparam=i2c(_arm)?[= ]off" $CONFIG; then
    sed $CONFIG -i -e "s/\(dtparam=i2c\(_arm\)?[= ]\)off/\1on/"
else
    ### TODO: Automate ###
    # raspi-config uses lua for this...
    echo "Existing I2C setting found in " $CONFIG
    echo "Currently this will need manually setting"
fi

if ! grep -q "^(#)*i2c[-_]dev" $MODULES; then
    echo "i2c-dev" >> $MODULES
else
    sed $MODULES -i -e "S/^#[[:space:]]*\(i2c[-_]dev\)/\1"
fi

dtparam i2c_arm=on
modprobe i2c-dev

################################################################################
# BrickPi Drivers

echo "Installing BrickPi3 C++ drivers"

git clone https://github.com/ownown/brickpi3_cpp.git $TMP

cd $TMP

# Dynamic lib
g++ -fPIC -c *.cpp
ld -shared *.o -o $SHARED_LIB

rm *.o

# Static lib
g++ -c *.cpp
ar rcs $STATIC_LIB *.o


# Copy to library folders
cp *.h $INCLUDE/
cp $SHARED_LIB $LIB/
cp $STATIC_LIB $LIB/

rm -rf $TMP

################################################################################
# ROS2

################################################################################
# End stuff

echo Done

################################################################################
