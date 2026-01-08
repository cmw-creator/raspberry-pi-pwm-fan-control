#!/bin/bash
# fan_control.sh
# 树莓派硬件PWM风扇控制脚本（使用pigpio）
# 功能：根据CPU温度自动调节风扇转速，支持启转/停转温度分离
# 硬件PWM，避免啸叫

# --- 配置部分 ---
FAN_GPIO=18            # 风扇连接GPIO18
TEMP_MIN_START=45000   # 风扇启动温度 (m°C)
TEMP_MIN_STOP=35000    # 风扇停止温度 (m°C)
TEMP_MAX=70000         # 风扇满速温度 (m°C)

PWM_MIN=250000         # 最低PWM频率/占空比值
PWM_MAX=1000000         # 最高PWM频率/占空比值

SLEEP_INTERVAL=2       # 循环间隔时间（秒）

# --- 启动pigpio守护进程 ---
if ! pgrep -x "pigpiod" > /dev/null; then
    echo "启动pigpiod守护进程..."
    sudo pigpiod
    sleep 1
fi

echo "初始化GPIO$FAN_GPIO为硬件PWM..."
# 初始化PWM
pigs hw 0 $FAN_GPIO 0

# 风扇运行状态变量
FAN_RUNNING=0

# --- 主循环 ---
while true
do
    # 读取CPU温度 (单位：m°C)
    CPU_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    
    # 判断风扇是否需要启动/停止
    if [ $FAN_RUNNING -eq 0 ] && [ $CPU_TEMP -ge $TEMP_MIN_START ]; then
        # 启动风扇
        FAN_RUNNING=1
        echo "$(date '+%Y-%m-%d %H:%M:%S') 温度=$((CPU_TEMP/1000))°C 风扇启动"
    elif [ $FAN_RUNNING -eq 1 ] && [ $CPU_TEMP -le $TEMP_MIN_STOP ]; then
        # 停止风扇
        FAN_RUNNING=0
        echo "$(date '+%Y-%m-%d %H:%M:%S') 温度=$((CPU_TEMP/1000))°C 风扇停止"
    fi

    # 计算PWM值
    if [ $FAN_RUNNING -eq 1 ]; then
        if [ $CPU_TEMP -ge $TEMP_MAX ]; then
            PWM_VALUE=$PWM_MAX
        else
            # 线性计算占空比
            PWM_VALUE=$((PWM_MIN + (CPU_TEMP - TEMP_MIN_START) * (PWM_MAX - PWM_MIN) / (TEMP_MAX - TEMP_MIN_START)))
        fi
        pigs hp $FAN_GPIO 25000 $PWM_VALUE  # 25kHz PWM，高频避免啸叫
    else
        pigs hp $FAN_GPIO 25000 0  # 停止PWM
    fi

    # 输出状态
    echo "$(date '+%Y-%m-%d %H:%M:%S') 温度=$((CPU_TEMP/1000))°C PWM=$PWM_VALUE"
    
    sleep $SLEEP_INTERVAL
done
