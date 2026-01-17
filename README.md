# Raspberry Pi PWM Fan Control

树莓派硬件PWM风扇控制脚本 / Raspberry Pi Hardware PWM Fan Control Script

## 功能介绍 / Features

- 根据CPU温度自动调节风扇转速 / Automatically adjust fan speed based on CPU temperature
- 支持启转/停转温度分离 / Support hysteresis control with separate start/stop temperatures
- 硬件PWM输出，高频率避免风扇啸叫 / Hardware PWM output at high frequency to avoid annoying noise
- 详细的温度和PWM日志 / Detailed temperature and PWM logging
- 使用pigpio库实现 / Implemented using pigpio library

## 安装教程 / Installation Guide

### 1. 安装pigpio库 / Install pigpio

```bash
# 更新系统 / Update system
sudo apt-get update
sudo apt-get upgrade

# 安装pigpio / Install pigpio
sudo apt-get install pigpio python3-pigpio

# 设置pigpio开机自启（可选） / Enable pigpio daemon on boot (Optional)
sudo systemctl enable pigpiod
sudo systemctl start pigpiod
```

### 2. 克隆或下载脚本 / Clone or Download Script

```bash
# 克隆仓库 / Clone repository
git clone https://github.com/cmw-creator/raspberry-pi-pwm-fan-control.git
cd raspberry-pi-pwm-fan-control

# 或 Or：手动下载 fan.sh 文件 / Download fan.sh manually
```

### 3. 赋予执行权限 / Grant Execution Permission

```bash
chmod +x fan.sh
```

## 接线教程 / Wiring Guide

### 硬件需求 / Hardware Requirements

- 树莓派 / Raspberry Pi (任何型号 / Any model with GPIO pins)
- PWM风扇（4针） / 4-pin PWM Fan
- 杜邦线 / Dupont wires
- （可选）电源模块或直接连接树莓派电源 / (Optional) Power module or direct connection to RPi power

### 接线步骤 / Wiring Steps

#### 四针PWM风扇接线 / 4-pin PWM Fan Wiring

```
PWM风扇 / PWM Fan:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
引脚 / Pin     | 颜色 / Color    | 树莓派 / Raspberry Pi
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. +12V       | 红色 / Red      | 电源 +12V (需要独立电源)
                                  | Power +12V (Requires separate power)
2. 地 / GND    | 黑色 / Black    | 地 / GND (任意地引脚)
                                  | GND (Any GND pin)
3. PWM 控制   | 黄色 / Yellow   | GPIO 18 (可配置)
                                  | GPIO 18 (Configurable)
4. 速度反馈   | 绿色 / Green    | 暂不使用 / Not used yet
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 树莓派GPIO引脚位置 / Raspberry Pi GPIO Pin Layout

```
树莓派40针GPIO引脚图 / Raspberry Pi 40-pin GPIO Layout:

      +3.3V | [1]  [2]  | +5V
 GPIO 2 (SDA) | [3]  [4]  | +5V
 GPIO 3 (SCL) | [5]  [6]  | GND
    GPIO 4    | [7]  [8]  | GPIO 14 (TXD)
        GND   | [9]  [10] | GPIO 15 (RXD)
    GPIO 17   | [11] [12] | GPIO 18 ← PWM风扇接线处
    GPIO 27   | [13] [14] | GND
    GPIO 22   | [15] [16] | GPIO 23
      +3.3V  | [17] [18] | GPIO 24
    GPIO 10   | [19] [20] | GND
     GPIO 9   | [21] [22] | GPIO 25
    GPIO 11   | [23] [24] | GPIO 8
        GND   | [25] [26] | GPIO 7
     GPIO 0   | [27] [28] | GPIO 1
     GPIO 5   | [29] [30] | GND
     GPIO 6   | [31] [32] | GPIO 12
    GPIO 13   | [33] [34] | GND
    GPIO 19   | [35] [36] | GPIO 16
    GPIO 26   | [37] [38] | GPIO 20
        GND   | [39] [40] | GPIO 21
```

**注意 / Note:** 建议使用GPIO 18（引脚12）连接PWM信号，因为树莓派硬件PWM通道1默认使用GPIO 18。
It is recommended to use GPIO 18 (Pin 12) for PWM signal as it is the default hardware PWM channel 1.

### 接线示意图 / Wiring Diagram

```
风扇 +12V (红) ──→ 电源 +12V / Power +12V
风扇 GND (黑)  ──→ 树莓派 GND / Raspberry Pi GND
风扇 PWM (黄)  ──→ 树莓派 GPIO 18 / Raspberry Pi GPIO 18
风扇 反馈 (绿) ──→ 暂不使用 / Not used yet
```

## 运行指南 / Usage Guide

### 编辑配置 / Edit Configuration

在运行前，根据需要修改 fan.sh 中的配置参数：
Before running, modify the configuration parameters in fan.sh as needed:

```bash
FAN_GPIO=18            # 风扇GPIO引脚 / Fan GPIO pin
TEMP_MIN_START=45000   # 风扇启动温度 45°C / Fan start temperature 45°C (in m°C)
TEMP_MIN_STOP=35000    # 风扇停止温度 35°C / Fan stop temperature 35°C (in m°C)
TEMP_MAX=70000         # 风扇满速温度 70°C / Max speed temperature 70°C (in m°C)
PWM_MIN=250000         # 最低PWM值 / Minimum PWM value
PWM_MAX=1000000        # 最高PWM值 / Maximum PWM value
SLEEP_INTERVAL=2       # 循环间隔（秒）/ Loop interval (seconds)
```

### 运行脚本 / Run Script

```bash
# 方法1：直接运行 / Method 1: Direct run
sudo ./fan.sh

# 方法2：后台运行 / Method 2: Run in background
sudo ./fan.sh &

# 方法3：使用nohup持久运行 / Method 3: Persistent run with nohup
sudo nohup ./fan.sh > fan.log 2>&1 &
```

### 设置开机自启 / Enable Auto-start on Boot

编辑 /etc/systemd/system/fan-control.service：
Edit /etc/systemd/system/fan-control.service:

```bash
sudo nano /etc/systemd/system/fan-control.service
```

添加以下内容 / Add the following content:

```ini
[Unit]
Description=Raspberry Pi PWM Fan Control
After=network.target

[Service]
Type=simple
ExecStart=/home/pi/fan.sh
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/fan-control.log
StandardError=append:/var/log/fan-control.log
User=root

[Install]
WantedBy=multi-user.target
```

启用服务 / Enable the service:

```bash
# 重新加载systemd配置 / Reload systemd configuration
sudo systemctl daemon-reload

# 启用服务 / Enable the service
sudo systemctl enable fan-control.service

# 启动服务 / Start the service
sudo systemctl start fan-control.service

# 查看服务状态 / Check service status
sudo systemctl status fan-control.service

# 查看日志 / View logs
sudo journalctl -u fan-control.service -f
```

## 故障排查 / Troubleshooting

### 问题1：权限不足 / Issue 1: Permission Denied

```bash
# 解决方案：使用sudo运行 / Solution: Run with sudo
sudo ./fan.sh
```

### 问题2：pigpio未启动 / Issue 2: pigpio daemon not running

```bash
# 手动启动pigpio / Manually start pigpio
sudo pigpiod

# 检查pigpio状态 / Check pigpio status
pgrep pigpiod
```

### 问题3：风扇不转 / Issue 3: Fan not spinning

- 检查接线是否正确 / Check wiring connections
- 确认GPIO号是否与配置匹配 / Verify GPIO number matches configuration
- 测试PWM输出 / Test PWM output:
  ```bash
  pigs hp 18 25000 500000  # 50%占空比测试 / 50% duty cycle test
  ```

### 问题4：查看实时CPU温度 / Issue 4: Check CPU temperature in real-time

```bash
# 查看CPU温度 / View CPU temperature
cat /sys/class/thermal/thermal_zone0/temp

# 实时监控 / Real-time monitoring
watch -n 1 'cat /sys/class/thermal/thermal_zone0/temp'
```

## 参数说明 / Parameters Explanation

| 参数 / Parameter | 说明 / Description | 默认值 / Default |
|---|---|---|
| `FAN_GPIO` | PWM风扇连接的GPIO引脚 / GPIO pin for PWM fan | 18 |
| `TEMP_MIN_START` | 风扇启动温度，低于此温度不启动 / Fan start temperature in m°C | 45000 (45°C) |
| `TEMP_MIN_STOP` | 风扇停止温度，低于此温度停止 / Fan stop temperature in m°C | 35000 (35°C) |
| `TEMP_MAX` | 风扇满速温度，达到此温度风扇全速运行 / Max speed temperature in m°C | 70000 (70°C) |
| `PWM_MIN` | 最低PWM值，风扇最低速度 / Minimum PWM value for lowest fan speed | 250000 |
| `PWM_MAX` | 最高PWM值，风扇最高速度 / Maximum PWM value for highest fan speed | 1000000 |
| `SLEEP_INTERVAL` | 主循环的休眠间隔（秒）/ Main loop sleep interval in seconds | 2 |

## 许可证 / License

MIT License - 详见 LICENSE 文件 / See LICENSE file for details

## 常见问题 / FAQ

**Q: 为什么选择GPIO 18？**
A: GPIO 18 是树莓派硬件PWM通道1的默认引脚，支持原生硬件PWM，避免占用CPU资源。

**Q: Why use GPIO 18?**
A: GPIO 18 is the default pin for Raspberry Pi hardware PWM channel 1, supporting native hardware PWM without consuming CPU resources.

---

**Q: PWM频率为什么是25kHz？**
A: 25kHz是高于人类听觉范围（20Hz-20kHz）的频率，可以有效避免风扇啸叫。

**Q: Why is PWM frequency 25kHz?**
A: 25kHz is above the human hearing range (20Hz-20kHz), effectively preventing fan noise.

---

**Q: 可以修改GPIO引脚吗？**
A: 可以，但需要使用支持硬件PWM的GPIO引脚。树莓派支持硬件PWM的引脚有限。

**Q: Can I change the GPIO pin?**
A: Yes, but you must use a GPIO pin that supports hardware PWM. Raspberry Pi has limited hardware PWM pins.

---

**Q: 需要独立电源吗？**
A: 建议使用独立的12V电源供电风扇，树莓派GPIO不能直接驱动高功率风扇。

**Q: Do I need a separate power supply?**
A: It is recommended to use an independent 12V power supply for the fan, as Raspberry Pi GPIO cannot directly drive high-power fans.

## 相关资源 / Resources

- [pigpio官网](http://abyz.me.uk/rpi/pigpio/) / [pigpio Official Site](http://abyz.me.uk/rpi/pigpio/)
- [树莓派GPIO引脚图](https://www.raspberrypi.com/documentation/) / [Raspberry Pi GPIO Pin Documentation](https://www.raspberrypi.com/documentation/)
- [树莓派官网](https://www.raspberrypi.org/) / [Raspberry Pi Official Site](https://www.raspberrypi.org/)
