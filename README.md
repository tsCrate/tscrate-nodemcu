# tsCrate NodeMcu files
This repository contains files to simplify NodeMCU device setup with [tsCrate.com](https://tscrate.com). Files are loaded onto an Espressif device (tested on the ESP8266) flashed with NodeMCU firmware. These files include code to run server and client modes for initial setup and long-term reporting to group devices on tsCrate.com.

After flashing firmware and loading files onto a device, the device will expose a Wi-Fi access point named "tsCrate#...". After connecting to the access point, users can navigate to 192.168.4.1 to setup a connection to tsCrate.com through Wi-Fi.

### Device Server
Server mode provides a simple setup process to connect a device.
1. Users connect to the device's Wi-Fi access point and are presented with a UI over http
3. Users select or enter a local Wi-Fi name and password
5. After the device connects to Wi-Fi, "Request Setup"
6. The device provides a setup code to the user
7. The user enters the code at tsCrate.com
9. The device switches to client mode on a successful setup

https://user-images.githubusercontent.com/10565441/118840445-a2b69280-b884-11eb-9109-eeed82fe1553.mp4


### Device Client
The client mode reports to tsCrate.com after initialization. A simple API is exposed for users to specify how and when values should be recorded.
```lua
LFS.registerReader(readInterval, readFunction, datasetName)
```

## Firmware Requirements
The following are required in user_config.h and user_modules.h for firmware builds (along with any modules required to communicate with connected hardware):

user_config.h
```c
#define CLIENT_SSL_ENABLE
#define LUA_FLASH_STORE 0x64000
```

user_modules.h
```c
#define LUA_USE_MODULES_HTTP
#define LUA_USE_MODULES_RTCTIME
#define LUA_USE_MODULES_SJSON
#define LUA_USE_MODULES_SNTP
```
