# Xray-Configer
A assistive tool for xray. It can generate config files from subscribe link, and keep the newest configrations automaticlly.

## Requirements
- [xray](https://github.com/XTLS/Xray-install/tree/main) installed
- root permission

You may need to replace download link with proxy server due to network problem, when you install xray. Also you can simply use the flower script to install xray:
```bash
GH_PROXY=https://ghfast.top/ bash -c "$(curl -L https://ghfast.top/https://github.com/MinionTim/xray-configer/raw/main/xray/install-release.sh)" @ install
```

## Usage
### Install
```bash
wget -N https://github.com/MinionTim/xray-configer/raw/main/xray-configer.sh && bash xray-configer.sh install
```
During installation, you will be asked to setup some environment variables:
- XRAY_SUB_URL: Your subscription url
- XRAY_CONFIG_PATH: The path of your xray config file. (Optional)

**You MUST define these environment variables in profile, such as `~/.bashrc`、`~/.zshrc`，to make sure the script can run properly in cron jobs.**


### (Optional) Install with proxy
- Use http proxy instead if network is not well
```bash
wget -N https://ghfast.top/https://github.com/MinionTim/xray-configer/raw/main/xray-configer.sh && GH_PROXY=https://ghfast.top/ bash xray-configer.sh install
```

### Run 
After installed successfully, you can start xray service with the latest config file.
```bash
xray-configer r
```
- More options, can be found by `xray-configer -h`
```bash
xray-configer [option]
```
| Option | Description |
| ----- | -------------- |
|    h \| help | print help info.         |
|   r \| update_restart | fetch xrayconfig and restart xray service  |
|    f \| fetch |fetch config only          |
|    t \| test |test network with proxy        |
|    i \| install | install the script         |
|    u \| uninstall | **uninstall** the script     |