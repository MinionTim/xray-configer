# Xray-Configer
A assistive tool for xray. It can generate config files from subscribe link, and keep the newest configrations automaticlly.

## Requirements
- [xray](https://github.com/XTLS/Xray-install/tree/main) installed
- root permission

You may need to replace download link with proxy server due to network problem, when you install xray. Also you can simply use the flower script to install xray:
```bash
bash -c "$(curl -L https://mirror.ghproxy.com/https://github.com/MinionTim/xray-configer/raw/main/xray/install-release.sh)" @ install
```

## Usage
### Install
```bash
wget -N https://github.com/MinionTim/xray-configer/raw/main/xray-configer.sh && bash xray-configer.sh install
```

- Use http proxy instead if network is not well
```bash
wget -N https://mirror.ghproxy.com/https://github.com/MinionTim/xray-configer/raw/main/xray-configer.sh && bash xray-configer.sh install
```

### Run 
```bash
xray-configer [option]
```
| Option | Description |
| ----- | -------------- |
|    h \| help | print help info.         |
|   r \| update_restart | fetch xrayconfig and restart xray   |
|    f \| fetch |fetch config only          |
|    t \| test |test network with proxy        |
|    i \| install | install the script         |
|    u \| uninstall | **uninstall** the script     |