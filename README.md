# NodeMcuCode
This repository contains files to load onto an Espressif device (tested on the ESP8266) flashed with NodeMCU firmware.

The files include code for the server and client modes to interact with [tsCrate.com](https://tscrate.com).

The server mode provides a simple setup process to connect a device.
1. Users connect to the device's Wi-Fi access point and are presented with a UI over http
3. Users select or enter a local Wi-Fi name and password
5. After the device connects to Wi-Fi, "Request Setup"
6. The device provides a setup code to the user
7. The user enters the code at tsCrate.com
9. The device switches to client mode on a successful setup

The client mode reports to tsCrate.com after initialization.

The client mode provides a simple API for users to specify how and when values should be recorded.
