# NodeMcuCode
# NodeMcuCode
This repository contains code for server and client modes to interact with tsCrate.com.

This code runs on an Espressif device (tested on the ESP8266) using NodeMCU firmware.

The server mode provides a simple setup process to connect a device to tsCrate.com
1. Users connect to the device's access point and are presented with a UI over http
3. Users select or enter a local Wi-Fi name and password
5. After the device connects to Wi-Fi, users click "Request Setup"
6. The device provides a setup code to the user
7. The user enters the code at tsCrate.com
9. The device switches to client mode on a successful setup

The client mode sends values to tsCrate.com after initialization.

The client mode provides a simple API for users to specify how and when values should be recorded.