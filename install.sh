#!/bin/bash
# ============================================
# Raspberry Pi PWM Fan Control - One-click Installer
# 树莓派PWM风扇控制 - 一键安装脚本
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/cmw-creator/raspberry-pi-pwm-fan-control"
SCRIPT_SOURCE="fan.sh"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="rpi-fan-control"
SERVICE_NAME="rpi-fan-control.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Raspberry Pi PWM Fan Control Installer${NC}"
echo -e "${CYAN}  树莓派 PWM 风扇控制 - 一键安装脚本${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ============================================
# Step 1: Check environment
# ============================================
echo -e "${YELLOW}[1/5]${NC} Checking environment... / 检查环境..."

# Check if running on Linux
if [ "$(uname)" != "Linux" ]; then
    echo -e "${RED}Error: This script is designed for Raspberry Pi (Linux).${NC}"
    echo -e "${RED}错误：此脚本仅适用于树莓派 (Linux)。${NC}"
    exit 1
fi

# Check for Raspberry Pi hardware
if [ -f /proc/device-tree/model ]; then
    RPI_MODEL=$(tr -d '\0' < /proc/device-tree/model)
    echo -e "  Detected: ${GREEN}$RPI_MODEL${NC}"
    echo -e "  检测到: ${GREEN}$RPI_MODEL${NC}"
else
    echo -e "${YELLOW}Warning: Cannot detect Raspberry Pi model. Proceeding anyway...${NC}"
    echo -e "${YELLOW}警告：无法检测树莓派型号，继续安装...${NC}"
fi

# Check for GPIO support
if [ ! -d /sys/class/gpio ] && [ ! -c /dev/gpiomem ]; then
    echo -e "${YELLOW}Warning: No GPIO interface detected. This may not be a Raspberry Pi.${NC}"
    echo -e "${YELLOW}警告：未检测到 GPIO 接口，这可能不是树莓派。${NC}"
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Note: Some steps need root. Will use sudo when needed.${NC}"
    echo -e "${YELLOW}提示：部分步骤需要 root 权限，将自动使用 sudo。${NC}"
fi

echo -e "${GREEN}  ✓ Environment OK / 环境检查通过${NC}"
echo ""

# ============================================
# Step 2: Install pigpio
# ============================================
echo -e "${YELLOW}[2/5]${NC} Installing pigpio... / 安装 pigpio..."

if command -v pigs &>/dev/null; then
    echo -e "  ${GREEN}✓ pigpio already installed / 已安装${NC}"
else
    echo -e "  Installing pigpio... / 正在安装..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq pigpio python3-pigpio
    echo -e "  ${GREEN}✓ pigpio installed / 安装完成${NC}"
fi

# Enable and start pigpiod daemon
sudo systemctl enable pigpiod 2>/dev/null || true
sudo systemctl start pigpiod 2>/dev/null || sudo pigpiod

# Wait for pigpiod to be ready
sleep 1
if pgrep -x "pigpiod" > /dev/null; then
    echo -e "  ${GREEN}✓ pigpiod is running / 运行中${NC}"
else
    echo -e "  ${RED}✗ pigpiod failed to start. Starting manually...${NC}"
    sudo pigpiod
    sleep 1
fi
echo ""

# ============================================
# Step 3: Install fan control script
# ============================================
echo -e "${YELLOW}[3/5]${NC} Installing fan control script... / 安装控制脚本..."

# Copy script from the same directory, or download from GitHub
if [ -f "$SCRIPT_SOURCE" ]; then
    echo -e "  Found local script / 找到本地脚本"
    sudo cp "$SCRIPT_SOURCE" "$INSTALL_DIR/$SCRIPT_NAME"
elif [ -f "$(dirname "$0")/$SCRIPT_SOURCE" ]; then
    echo -e "  Found script in same directory / 找到同目录脚本"
    sudo cp "$(dirname "$0")/$SCRIPT_SOURCE" "$INSTALL_DIR/$SCRIPT_NAME"
else
    echo -e "  Downloading from GitHub... / 从 GitHub 下载..."
    if command -v curl &>/dev/null; then
        sudo curl -sL "$REPO_URL/raw/main/fan.sh" -o "$INSTALL_DIR/$SCRIPT_NAME"
    elif command -v wget &>/dev/null; then
        sudo wget -q "$REPO_URL/raw/main/fan.sh" -O "$INSTALL_DIR/$SCRIPT_NAME"
    else
        echo -e "${RED}Error: curl or wget required / 需要 curl 或 wget${NC}"
        exit 1
    fi
fi

sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo -e "  ${GREEN}✓ Installed to $INSTALL_DIR/$SCRIPT_NAME${NC}"
echo -e "  ${GREEN}✓ 已安装到 $INSTALL_DIR/$SCRIPT_NAME${NC}"
echo ""

# ============================================
# Step 4: Configure (ask user for GPIO pin)
# ============================================
echo -e "${YELLOW}[4/5]${NC} Configuration / 配置"

# Check if config exists
CONFIG_FILE="/etc/rpi-fan-control.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "  Default settings will be used: / 将使用默认配置："
    echo -e "    GPIO Pin:              18"
    echo -e "    Start Temp:            45°C"
    echo -e "    Stop Temp:             35°C"
    echo -e "    Max Speed Temp:        70°C"
    echo -e "    PWM Min/Max:          250000 / 1000000"
    echo ""
    
    read -r -p "  Change GPIO pin? (default 18) [18]: " GPIO_INPUT
    GPIO_INPUT=${GPIO_INPUT:-18}
    
    read -r -p "  Fan start temperature (°C) [45]: " START_INPUT
    START_INPUT=${START_INPUT:-45}
    
    read -r -p "  Fan stop temperature (°C) [35]: " STOP_INPUT
    STOP_INPUT=${STOP_INPUT:-35}
    
    read -r -p "  Max speed temperature (°C) [70]: " MAX_INPUT
    MAX_INPUT=${MAX_INPUT:-70}

    # Create config file
    sudo tee "$CONFIG_FILE" > /dev/null << EOF
# Raspberry Pi PWM Fan Control Configuration
# 树莓派 PWM 风扇控制配置文件
# Generated by install.sh / 由安装脚本生成

FAN_GPIO=$GPIO_INPUT
TEMP_MIN_START=$((START_INPUT * 1000))
TEMP_MIN_STOP=$((STOP_INPUT * 1000))
TEMP_MAX=$((MAX_INPUT * 1000))
PWM_MIN=250000
PWM_MAX=1000000
SLEEP_INTERVAL=2
EOF
    
    echo -e "  ${GREEN}✓ Configuration saved to $CONFIG_FILE${NC}"
    echo -e "  ${GREEN}✓ 配置文件已保存到 $CONFIG_FILE${NC}"
else
    echo -e "  ${GREEN}✓ Config file already exists: $CONFIG_FILE${NC}"
    echo -e "  ${GREEN}✓ 配置文件已存在: $CONFIG_FILE${NC}"
    echo ""
    echo -e "  To reconfigure, delete the file and re-run:"
    echo -e "  如需重新配置，删除配置文件后重试："
    echo -e "    sudo rm $CONFIG_FILE && sudo ./install.sh"
fi
echo ""

# ============================================
# Step 5: Create and start systemd service
# ============================================
echo -e "${YELLOW}[5/5]${NC} Setting up systemd service... / 设置系统服务..."

# Copy the wrapper script that sources config
sudo tee "$INSTALL_DIR/$SCRIPT_NAME" > /dev/null << 'SCRIPT'
#!/bin/bash
# ============================================
# Raspberry Pi PWM Fan Control
# Generated by install.sh
# ============================================

CONFIG_FILE="/etc/rpi-fan-control.conf"

# Load config / 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Defaults / 默认值
    FAN_GPIO=18
    TEMP_MIN_START=45000
    TEMP_MIN_STOP=35000
    TEMP_MAX=70000
    PWM_MIN=250000
    PWM_MAX=1000000
    SLEEP_INTERVAL=2
fi

# Start pigpiod if not running / 启动pigpiod
if ! pgrep -x "pigpiod" > /dev/null; then
    echo "Starting pigpiod daemon..."
    pigpiod
    sleep 1
fi

echo "Initializing GPIO${FAN_GPIO} as hardware PWM..."
pigs hw 0 $FAN_GPIO 0

FAN_RUNNING=0

while true; do
    CPU_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    
    # Hysteresis control / 滞后控制
    if [ $FAN_RUNNING -eq 0 ] && [ $CPU_TEMP -ge $TEMP_MIN_START ]; then
        FAN_RUNNING=1
        echo "$(date '+%Y-%m-%d %H:%M:%S') Temp=$((CPU_TEMP/1000))°C Fan Started"
    elif [ $FAN_RUNNING -eq 1 ] && [ $CPU_TEMP -le $TEMP_MIN_STOP ]; then
        FAN_RUNNING=0
        echo "$(date '+%Y-%m-%d %H:%M:%S') Temp=$((CPU_TEMP/1000))°C Fan Stopped"
    fi

    if [ $FAN_RUNNING -eq 1 ]; then
        if [ $CPU_TEMP -ge $TEMP_MAX ]; then
            PWM_VALUE=$PWM_MAX
        else
            PWM_VALUE=$((PWM_MIN + (CPU_TEMP - TEMP_MIN_START) * (PWM_MAX - PWM_MIN) / (TEMP_MAX - TEMP_MIN_START)))
        fi
        pigs hp $FAN_GPIO 25000 $PWM_VALUE
    else
        pigs hp $FAN_GPIO 25000 0
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') Temp=$((CPU_TEMP/1000))°C PWM=$PWM_VALUE"
    sleep $SLEEP_INTERVAL
done
SCRIPT

sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Create systemd service file
sudo tee "$SERVICE_PATH" > /dev/null << EOF
[Unit]
Description=Raspberry Pi PWM Fan Control
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$SCRIPT_NAME
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/rpi-fan-control.log
StandardError=append:/var/log/rpi-fan-control.log

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME" 2>/dev/null
sudo systemctl restart "$SERVICE_NAME" 2>/dev/null || true

# Verify service
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "  ${GREEN}✓ Service $SERVICE_NAME is running / 服务运行中${NC}"
else
    echo -e "  ${YELLOW}⚠ Service status: $(systemctl is-active "$SERVICE_NAME")${NC}"
    echo -e "  Check with: sudo systemctl status $SERVICE_NAME"
    echo -e "  检查状态: sudo systemctl status $SERVICE_NAME"
fi
echo ""

# ============================================
# Done
# ============================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete! / 安装完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  ${CYAN}Commands / 常用命令:${NC}"
echo -e "  Check status / 查看状态:  ${GREEN}sudo systemctl status $SERVICE_NAME${NC}"
echo -e "  View logs / 查看日志:     ${GREEN}sudo journalctl -u $SERVICE_NAME -f${NC}"
echo -e "  View temp / 查看温度:     ${GREEN}cat /sys/class/thermal/thermal_zone0/temp${NC}"
echo -e "  Stop service / 停止服务:  ${GREEN}sudo systemctl stop $SERVICE_NAME${NC}"
echo -e "  Start service / 启动服务: ${GREEN}sudo systemctl start $SERVICE_NAME${NC}"
echo ""
echo -e "  ${CYAN}Configuration / 配置:${NC}"
echo -e "  Config file / 配置文件:   ${GREEN}$CONFIG_FILE${NC}"
echo -e "  Edit then restart:         ${GREEN}sudo systemctl restart $SERVICE_NAME${NC}"
echo ""
echo -e "  ${CYAN}Uninstall / 卸载:${NC}"
echo -e "  ${GREEN}sudo systemctl stop $SERVICE_NAME${NC}"
echo -e "  ${GREEN}sudo systemctl disable $SERVICE_NAME${NC}"
echo -e "  ${GREEN}sudo rm $SERVICE_PATH $INSTALL_DIR/$SCRIPT_NAME $CONFIG_FILE${NC}"
echo -e "  ${GREEN}sudo systemctl daemon-reload${NC}"
echo ""
echo -e "${GREEN}⭐ If you find this useful, please star the repo!${NC}"
echo -e "${GREEN}⭐ 如果觉得有用，请给个 Star！${NC}"
echo -e "${GREEN}   $REPO_URL${NC}"
echo ""
