#!/bin/zsh

source "$(dirname $0)/helper.zsh"
source "$(dirname $0)/local.env"

time=$(date +%s)
stats_out="/tmp/argos_stats"

# CPU
num_cpus=$(nproc --all)
cpu_load=$(cat /proc/loadavg | cut -f1 -d' ')
cpu_freq=$(lscpu | grep "CPU MHz" | awk '{ printf "%.2f", $3/1024 }')
cpu_pct=$(($cpu_load/$num_cpus))

cpu_color=$WHITE
if [[ $cpu_pct -gt 0.7 ]]; then
    cpu_color=$ORANGE
elif [[ $cpu_pct -gt 0.5 ]]; then
    cpu_color=$YELLOW
fi
cpu_out="$cpu_load/$cpu_freq GHz"

# MEM
mem_info=$(cat /proc/meminfo)
mem_total=$(echo $mem_info | grep "MemTotal" | awk '{ printf "%.2f", $2/1024/1024 }')
mem_free=$(echo $mem_info | grep "MemAvailable" | awk '{ printf "%.2f", $2/1024/1024 }')
mem_pct=$(($mem_free/$mem_total))

mem_color=$WHITE
if [[ $mem_pct -lt 0.2 ]]; then
    mem_color=$ORANGE
elif [[ $mem_pct -lt 0.4 ]]; then
    mem_color=$YELLOW
fi
mem_out="$mem_free GB"

# DISK
disk_color=$WHITE
disk_down_color=$WHITE
disk_up_color=$WHITE
disk_stats=$(\df $DISK_PART | grep "$DISK_PART")
disk_total=$(echo $disk_stats | awk '{ printf "%.2f", $2/1024/1024 }')
disk_free=$(echo $disk_stats | awk '{ printf "%.2f", $4/1024/1024 }')
disk_pct=$(($disk_free/$disk_total))

sec_size=$(cat /sys/block/$DISK_DEV/queue/hw_sector_size)
disk_stats=$(cat /proc/diskstats | grep "$DISK_DEV ")
disk_rops=$(echo $disk_stats | awk '{ printf "%i", $4 }')
disk_rsec=$(echo $disk_stats | awk '{ printf "%i", $6 }')
disk_wops=$(echo $disk_stats | awk '{ printf "%i", $8 }')
disk_wsec=$(echo $disk_stats | awk '{ printf "%i", $10 }')

disk_out="..."
disk_io_write_out="..."
disk_io_read_out="..."

# NET
net_color=$WHITE
net_down_color=$WHITE
net_up_color=$WHITE
net_stats=$(cat /proc/net/dev | grep "$NET_IFACE")
net_rx=$(echo $net_stats | awk '{ printf "%i", $2 }')
net_tx=$(echo $net_stats | awk '{ printf "%i", $10 }')

net_out="..."
net_io_rx_out="..."
net_io_tx_out="..."

if [[ -d $stats_out ]]; then
    time_diff=$(($time - $(cat $stats_out/time)))

    # DISK CUMULATIVE
    disk_rops_diff=$((($disk_rops - $(cat $stats_out/disk_rops)) / $time_diff))
    disk_rbytes=$(((($disk_rsec - $(cat $stats_out/disk_rsec)) / $time_diff) * $sec_size))
    disk_wops_diff=$((($disk_wops - $(cat $stats_out/disk_wops)) / $time_diff))
    disk_wbytes=$(((($disk_wsec - $(cat $stats_out/disk_wsec)) / $time_diff) * $sec_size))

    disk_tops=$(($disk_rops_diff + $disk_wops_diff))
    disk_tbytes=$(($disk_rbytes + $disk_wbytes))

    if [[ $disk_tops -gt $DISK_OPS_THRESH ]] || [[ $disk_tbytes -gt $DISK_BYTES_THRESH ]]; then
        disk_color=$ORANGE
    fi

    if [[ $disk_wops_diff -gt 0 ]] || [[ $disk_wbytes -gt 0 ]]; then
        disk_down_color=$RED
    fi

    if [[ $disk_rops_diff -gt 0 ]] || [[ $disk_rbytes -gt 0 ]]; then
        disk_up_color=$RED
    fi

    disk_out="$disk_free GB"
    disk_io_write_out="WRITE: $(human_readable $disk_wbytes) ($disk_wops_diff)"
    disk_io_read_out="READ: $(human_readable $disk_rbytes) ($disk_rops_diff)"
    
    # NET CUMULATIVE
    net_rx_diff=$((($net_rx - $(cat $stats_out/net_rx)) / $time_diff))
    net_tx_diff=$((($net_tx - $(cat $stats_out/net_tx)) / $time_diff))
    net_all=$(($net_rx_diff + $net_tx_diff))

    if [[ $net_all -gt $NET_BYTES_THRESH ]]; then
        net_color=$ORANGE
    fi

    if [[ $net_rx_diff -gt 0 ]]; then
        net_down_color=$RED
    fi

    if [[ $net_tx_diff -gt 0 ]]; then
        net_up_color=$RED
    fi
    net_out="$(human_readable $(($net_rx + $net_tx)))"
    net_io_rx_out="RX: $(human_readable $net_rx_diff)"
    net_io_tx_out="TX: $(human_readable $net_tx_diff)"
else
    mkdir $stats_out
fi

echo -n $time > $stats_out/time

# DISK SAVE
echo -n $disk_rops > $stats_out/disk_rops
echo -n $disk_rsec > $stats_out/disk_rsec
echo -n $disk_wops > $stats_out/disk_wops
echo -n $disk_wsec > $stats_out/disk_wsec

# NET SAVE
echo -n $net_rx > $stats_out/net_rx
echo -n $net_tx > $stats_out/net_tx

main="<span color='$net_color'>NET: $net_out</span>"
main+=" <span color='$net_down_color'>↓</span><span color='$net_up_color'>↑</span>"
main+=" • <span color='$disk_color'>DISK: $disk_out</span>"
main+=" <span color='$disk_down_color'>↓</span><span color='$disk_up_color'>↑</span>"
main+=" • <span color='$mem_color'>RAM: $mem_out</span>"
main+=" • <span color='$cpu_color'>CPU: $cpu_out</span>"

echo "$main"
echo "---"
echo "<span underline='single'>Stats</span>"
echo "<span>    </span>$main"
echo "<span underline='single'>Temperatures</span>"
echo "<span color='$WHITE'>    CPU: $(($(cat /sys/class/thermal/thermal_zone8/temp) / 1000)) ° C</span>"
echo "<span color='$WHITE'>    MEM: $(($(cat /sys/class/thermal/thermal_zone1/temp) / 1000)) ° C</span>"
echo "<span color='$WHITE'>    AMB: $(($(cat /sys/class/thermal/thermal_zone5/temp) / 1000)) ° C</span>"
echo "<span underline='single'>Disk IO</span>"
echo "<span color='$WHITE'>    $disk_io_write_out</span>"
echo "<span color='$WHITE'>    $disk_io_read_out</span>"
echo "<span underline='single'>Network IO</span>"
echo "<span color='$WHITE'>    $net_io_rx_out</span>"
echo "<span color='$WHITE'>    $net_io_tx_out</span>"
