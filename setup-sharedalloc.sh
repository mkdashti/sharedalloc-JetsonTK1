#!/bin/bash
cd NVIDIA_CUDA-6.5_Samples/1_Utilities/deviceQuery
./deviceQuery
echo "echo 0 > /sys/devices/system/cpu/cpuquiet/tegra_cpuquiet/enable" | sudo -s
echo "echo 1 > /sys/devices/system/cpu/cpu0/online" | sudo -s
echo "echo 1 > /sys/devices/system/cpu/cpu1/online" | sudo -s
echo "echo 1 > /sys/devices/system/cpu/cpu2/online" | sudo -s
echo "echo 1 > /sys/devices/system/cpu/cpu3/online" | sudo -s
echo "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" | sudo -s

echo "echo 852000000 > /sys/kernel/debug/clock/override.gbus/rate" | sudo -s
echo "echo 1 > /sys/kernel/debug/clock/override.gbus/state" | sudo -s

echo "echo 924000000 > /sys/kernel/debug/clock/override.emc/rate" | sudo -s
echo "echo 1 > /sys/kernel/debug/clock/override.emc/state" | sudo -s

echo "echo -1 > /proc/sys/kernel/perf_event_paranoid" | sudo -s
echo "echo 0 > /proc/sys/kernel/kptr_restrict" | sudo -s

cd /home/ubuntu/kernel/gpu_hook
make
sudo insmod ./gpu_hook.ko

cat /etc/nv_tegra_release
