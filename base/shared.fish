#!/usr/bin/env fish

set -x dataDir "/data/juushFiles"
function disk_usage -d "Get disk usage of $dataDir as a percentage"
    set du_pct (df -H $dataDir | tail -n 1 | awk '{print $5}')
    # remove the % sign
    set du_pct (string sub -s 1 -l -1 $du_pct)
    echo $du_pct
end


set min_disk_usage_for_pruning 50
function check_if_disk_needs_pruning
    set disk_usage (disk_usage)
    if math "$disk_usage > $min_disk_usage_for_pruning"
        echo "Disk usage is $disk_usage%, pruning..."
        return 0
    else
        echo "Disk usage is $disk_usage%, no need to prune"
        return 1
    end
end

