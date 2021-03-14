# Setting up the Pi

## Installing and setting up Ubuntu

- *Instructions from [here](https://ubuntu.com/tutorials/how-to-install-ubuntu-on-your-raspberry-pi#1-overview)*
- Download the Rasperry Pi Imager
  - [Ubuntu](https://downloads.raspberrypi.org/imager/imager_amd64.deb)
  - [Windows](https://downloads.raspberrypi.org/imager/imager.exe)
  - [Mac](https://downloads.raspberrypi.org/imager/imager.dmg)
- Choose Ubuntu Server 64-bit 20.04 LTS
- Choose your SD card and write image to it

## Setup WiFi

- *If you're using ethernet for setup, you can skip this for now if you want as it will automatically connect*
- Remove and re-insert the SD card
- Open the system-boot partition
- Open the network-config
- Uncomment the `wifis` section and fill in your WiFi details:

```YAML
wifis:
  wlan0:
  dhcp4: true
  optional: true
  access-points:
    <wifi network name>:
      password: <wifi password>
```

## Connect to the Pi

- Eject the SD card and insert into the Raspberry Pi
- Boot the Pi
- Search for the RPi's IP address on the network
  - You can use arp or arp-scan on Linux, or a client like Angry IP or Advanced IP Scanner on Windows

```bash
# With arp
arp -a | grep -iP "(b8:27:eb|dc:a6:32)"


# With arp-scan

# If you don't have arp-scan installed
sudo apt update && sudo apt install -y arp-scan

# Scan the network and return the details for any Raspberry Pis found
sudo arp-scan -l | grep -i raspberry
```

- Connect to the Pi using SSH.
- The default login username and password are both `ubuntu`

```bash
ssh ubuntu@<ip address>
```

- You will recieve the following prompt the first time. Type yes and hit enter

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

- On connecting for the first time, you will be asked to change the password, and kicked out as soon as you have, so you'll need to ssh to the Pi twice: once to change the password, and again to actually access it

## [Optional] Cancel unattended-upgrades

- Ubuntu Server has the `unattended-upgrades` script set to run by default. I don't like it.
- To disable run the following and choose no. Now you have manual control over upgrades

```bash
sudo dpkg-recongfigure unattended-upgrades
```

## Configure Pi

- Run the setup script as sudo
- This will:
  - update packages
  - install dependencies
  - enable SPI and I2C
  - download, build, and install the BrickPi3 C++ libraries
  - install ROS2
  - set up ROS2 workspace and download robot control code (not yet implemented, for now follow [ROS2 documentation](https://docs.ros.org/en/foxy/Tutorials/Workspace/Creating-A-Workspace.html) on setting up a workspace
