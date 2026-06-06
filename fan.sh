#!/bin/bash
# fan_control.sh
# Raspberry Pi Hardware PWM Fan Control Script using pigpio
# 树莓派硬件PWM风扇控制脚本（使用pigpio）
# 
# Features / 功能：
# - Automatically adjust fan speed based on CPU temperature / 根据CPU温度自动调节风扇转速
# - Support hysteresis control with separate start/stop temperatures / 支持启转/停转温度分离
# - Hardware PWM output, high frequency to avoid fan noise / 硬件PWM，避免啸叫

# ============================================
# Configuration Section / 配置部分
# ============================================
FAN_GPIO=18            # Fan connected GPIO pin / 风扇连接GPIO18
TEMP_MIN_START=45000   # Fan start temperature in m°C / 风扇启动温度 (m°C)
TEMP_MIN_STOP=35000    # Fan stop temperature in m°C / 风扇停止温度 (m°C)
TEMP_MAX=70000         # Fan full speed temperature in m°C / 风扇满速温度 (m°C)

PWM_MIN=250000         # Minimum PWM frequency/duty cycle value / 最低PWM频率/占空比值
PWM_MAX=1000000        # Maximum PWM frequency/duty cycle value / 最高PWM频率/占空比值

SLEEP_INTERVAL=2       # Loop sleep interval in seconds / 循环间隔时间（秒）

# ============================================
# Start pigpio daemon / 启动pigpio守护进程
# ============================================
if ! pgrep -x "pigpiod" > /dev/null; then
    echo "Starting pigpiod daemon... / 启动pigpiod守护进程..."
    sudo pigpiod
    sleep 1
fi

echo "Initializing GPIO$FAN_GPIO as hardware PWM... / 初始化GPIO$FAN_GPIO为硬件PWM..."
# Initialize PWM / 初始化PWM
pigs hw 0 $FAN_GPIO 0

# Fan running status variable / 风扇运行状态变量
FAN_RUNNING=0

# ============================================
# Main Loop / 主循环
# ============================================
while true
do
    # Read CPU temperature (unit: m°C) / 读取CPU温度 (单位：m°C)
    CPU_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    
    # Check if fan needs to start/stop / 判断风扇是否需要启动/停止
    if [ $FAN_RUNNING -eq 0 ] && [ $CPU_TEMP -ge $TEMP_MIN_START ]; then
        # Start fan / 启动风扇
        FAN_RUNNING=1
        echo "$(date '+%Y-%m-%d %H:%M:%S') Temperature=$((CPU_TEMP/1000))°C Fan Started / 温度=$((CPU_TEMP/1000))°C 风扇启动"
    elif [ $FAN_RUNNING -eq 1 ] && [ $CPU_TEMP -le $TEMP_MIN_STOP ]; then
        # Stop fan / 停止风扇
        FAN_RUNNING=0
        echo "$(date '+%Y-%m-%d %H:%M:%S') Temperature=$((CPU_TEMP/1000))°C Fan Stopped / 温度=$((CPU_TEMP/1000))°C 风扇停止"
    fi

    # Calculate PWM value / 计算PWM值
    if [ $FAN_RUNNING -eq 1 ]; then
        if [ $CPU_TEMP -ge $TEMP_MAX ]; then
            # Full speed / 全速
            PWM_VALUE=$PWM_MAX
        else
            # Linear calculation of duty cycle / 线性计算占空比
            PWM_VALUE=$((PWM_MIN + (CPU_TEMP - TEMP_MIN_START) * (PWM_MAX - PWM_MIN) / (TEMP_MAX - TEMP_MIN_START)))
        fi
        # 25kHz PWM, high frequency to avoid fan noise / 25kHz PWM，高频避免啸叫
        pigs hp $FAN_GPIO 25000 $PWM_VALUE
    else
        # Stop PWM / 停止PWM
        pigs hp $FAN_GPIO 25000 0
    fi

    # Output status / 输出状态
    echo "$(date '+%Y-%m-%d %H:%M:%S') Temperature=$((CPU_TEMP/1000))°C PWM=$PWM_VALUE / 温度=$((CPU_TEMP/1000))°C PWM=$PWM_VALUE"
    
    # Sleep for interval / 休眠指定时间
    sleep $SLEEP_INTERVAL
done
