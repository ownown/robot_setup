#! /bin/bash

################################################################################
## Name:    setup.sh                                                          ##
## Version: 0.0.1                                                             ##
## Date:    2021-03-14                                                        ##
## Repo:    https://github.com/ownown/robot_setup                             ##
## Author:  Oliver Newman                                                     ##
## Email:   info@olivernewman.co.uk                                           ##
## License: MIT                                                               ##
##                                                                            ##
## Description:                                                               ##
## This will set up a Pi3 with Ubuntu 20.04 for use with ROS2, the BrickPi3   ##
## and C++. It will:                                                          ##
##      * Install required libraries such as wiringpi                         ##
##      * Set up SPI                                                          ##
##      * Set up I2C for use with the Grove port if desired                   ##
##      * Download, build, and install the BrickPi3 C++ libraries (my         ##
##          slightly modified versions)                                       ##
##      * Install and set up ROS2                                             ##
## It draws on the raspi-config and Dexter Industries BrickPi3 setup scripts, ##
## as well as the ROS2 documentation                                          ##
##                                                                            ##
## Links:                                                                     ##
## https://archive.raspberrypi.org/debian/pool/main/r/raspi-config/           ##
## https://github.com/DexterInd/BrickPi3                                      ##
## https://github.com/ownown/brickpi3_cpp                                     ##
## https://docs.ros.org/en/foxy/                                              ##
##                                                                            ##
################################################################################

################################################################################
################################################################################
################################################################################
# Contents
#
# * Constants
#   * Defines useful constants for use throughout the script. Separated into the
#       sections in which they (first) appear.
# * Initial Setup
#   * Updates installed packages and installs dependencies
# * SPI and I2C
#   * Enables SPI and I2C on the RPi
# * BrickPi3 libraries
#   * Downloads, builds, and installs my version of the BrickPi3 libraries
#   * I found that I could not properly build the Dexter Industry ones, and I
#       had to include the cpp file in my scripts, which obviously isn't ideal.
#   * I've not changed any of the actual code yet, just separated the SPI
#       functions from the rest of the code and labelled some global variables
#       as extern.
#   * They now behave slightly better (though they do through a bunch of 
#       compiler warnings).
# * ROS2
#   * Add ROS2 to the list of repositories and install
# * End stuff

################################################################################
################################################################################
################################################################################
# Constants

# SPI and I2C
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt
MODULES=/etc/modules
UDEV_RULES=/etc/udec/rules.d

# BrickPi3 libraries
TMP=/tmp/BrickPi3
SHARED_LIB=libbrickpi.so
STATIC_LIB=libbrickpi.a
LIB=/usr/lib
INCLUDE=/usr/include

# ROS2
HOME=/home/ubuntu

################################################################################
################################################################################
################################################################################
# Initial setup

################################################################################
# Some of the commands we will use require elevated privileges
if [ $(id -u) -ne 0 ]; then
    echo "Script must be run with sudo"
    exit 1
fi

################################################################################
# Update the system
sudo apt update && sudo apt upgrade -y


################################################################################
# Install additional libraries
# Python shouldn't be needed
sudo apt install -y git build-essential g++ libffi-dev libraspberrypi-bin \
                     libi2c-dev i2c-tools wiringpi openocd curl gnupg2 \
                     lsb-release # python3-dev\
                     #python3-setuptools python3-pip python-is-python3

################################################################################
# Check for UTF-8 support
# https://docs.ros.org/en/foxy/Installation/Linux-Install-Debians.html
if ! locale | grep -qi utf-8; then
    echo "locale does not support UTF-8"
    sudo apt install locales
    sudo locale-gen en_GB en_GB.UTF-8
    sudo apt update-locale LC_ALL=en_GB.UTF-8 LANG=en_GB.UTF-8
    export LANG=en_GB.UTF-8
fi

################################################################################
################################################################################
################################################################################
# SPI and I2C

################################################################################
# Enable SPI

echo "Setting up SPI"

################################################################################
# Enable SPI in the boot config
# This is modified from raspi-config
if ! grep -q -E "dtparam=spi[= ]on" $CONFIG; then
    echo "dtparam=spi=on" > $CONFIG
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

################################################################################
# Enable SPI in /etc/modules

if ! grep -q "^(#)*( )*spi-dev" $MODULES; then
    echo "spi-dev" >> $MODULES
else
    sed $MODULES -i -e "S/^#[[:space:]]*\(spi-dev\)/\1"
fi

################################################################################
# Remove from blacklist

if ! [ -e $BLACKLIST ]; then
    touch $BLACKLIST
else
    # This should never happen as it's not a part of Ubuntu, but hey, just in 
    # case
    sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*spi[-_]bcm2708\)/\1/"
fi

################################################################################

sudo dtparam spi=on

################################################################################
# Enable I2C
echo "Setting up I2C"

################################################################################
# Enable I2C in the boot config

if ! grep -q -E "dtparam=i2c(_arm)?[= ]on" $CONFIG; then
    echo "dtparam=i2c_arm=on" > $CONFIG
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

################################################################################
# Enable I2C in /etc/modules

if ! grep -q "^(#)*i2c[-_]dev" $MODULES; then
    echo "i2c-dev" >> $MODULES
else
    sed $MODULES -i -e "S/^#[[:space:]]*\(i2c[-_]dev\)/\1"
fi

################################################################################
# Remove from blacklist

################################################################################

sudo dtparam i2c_arm=on
sudo modprobe i2c-dev

################################################################################
# Create groups

# Allows us to user the SPI without root privileges
sudo groupadd --system spi
sudo adduser ubuntu spi

if ! [ -e $UDEV_RULES/90-spi.rules ] || ! $( grep -iq spi $UDEV_RULES/90-spi.rules ); then
    export $UDEV_RULES
    sudo bash -c 'echo "SUBSYSTEM==\"spidev\", GROUP=\"spi\"" > $UDEV_RULES/90-spi.rules'
else
    echo "Existing SPI settings in $UDEV_RULES/90-spi.rules"
fi

################################################################################
################################################################################
################################################################################
# BrickPi3 libraries

echo "Installing BrickPi3 C++ drivers"

git clone https://github.com/ownown/brickpi3_cpp.git $TMP

cd $TMP

################################################################################
# Dynamic lib

g++ -fPIC -c *.cpp
ld -shared *.o -o $SHARED_LIB

rm *.o

################################################################################
# Static lib

g++ -c *.cpp
ar rcs $STATIC_LIB *.o

################################################################################
# Copy to library folders

cp *.h $INCLUDE/
cp $SHARED_LIB $LIB/
cp $STATIC_LIB $LIB/

################################################################################
# Tidy up

rm -rf $TMP

################################################################################
################################################################################
################################################################################
# ROS2

echo "Installing ROS2"

cd $HOME

################################################################################
# Add the repo to the system

curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
sudo sh -c 'echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'

################################################################################
# Update apt cache and install
sudo apt update
# No point installing ros-foxy-desktop on the RPi as we have no desktop 
# environment
sudo apt install ros-foxy-ros-base

################################################################################
# Add to bashrc

echo "source /opt/ros/foxy/setup.bash" > $HOME/.bashrc
source $HOME/.bashrc

################################################################################
# Allow for autocompletion of ROS CLI arguments

pip3 install -U argcomplete

################################################################################
# Environment setup

# cd $HOME
mkdir -p $HOME/dev_ws/src
# cd $HOME/dev_ws/src
# git clone https://github.com/ros/ros_tutorials.git -b foxy-devel
# cd $HOME/dev_ws
# rosdep install -i --from-path src --rosdistro foxy -y
# colcon build

################################################################################
################################################################################
################################################################################
# End stuff

echo Done

################################################################################
################################################################################
################################################################################
