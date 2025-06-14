#! /bin/bash

# set -uo pipefail
# set -x

typeset SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
typeset current_date_time="`date +%Y%m%d%H%M`"

function print_usage {
        echo "[usage] ./setup.sh [HOST/VMS] EXP-SPECIFIC"
        echo "HOST: None"
        echo "VMS: HOST_NUM"
}

if [ $# -lt 1 ]; then
        print_usage
        exit -1
fi

typeset TASK_TYPE=$1

source $SCRIPT_DIR/utilities.sh

if [ $TASK_TYPE = "HOST" ]; then
        if [ $# != 1 ]; then
                print_usage
                exit -1
        fi

        # tool chains
        sudo apt-get install -y cmake gcc-12 g++-12 clang-15 clang++-15 lld-15 cargo

        # libraries
        sudo apt-get install -y libboost-all-dev libjemalloc-dev libgoogle-glog-dev libgtest-dev

        # required by VM-based emulation
        sudo apt-get install -y python3 python3-pip mkosi ovmf numactl
        sudo pip3 install pyroute2      # use sudo because root user needs it

        # required by parsing and plotting
        pip3 install pandas matplotlib
        sudo apt-get install -y msttcorefonts -qq
        rm ~/.cache/matplotlib -rf           # remove cache

        # setup ssh key
        [ -f $HOME/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa
        cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys

        exit 0
elif [ $TASK_TYPE = "VMS" ]; then
        if [ $# != 2 ]; then
                print_usage
                exit -1
        fi
        typeset HOST_NUM=$2
        echo "Setting up VMs..."

        # sync kernel module
        echo "Sync kernel module..."
        sync_files $SCRIPT_DIR/../dependencies/kernel_module/cxl_init /root/cxl_init $HOST_NUM
        sync_files $SCRIPT_DIR/../dependencies/kernel_module/cxl_recover_meta /root/cxl_recover_meta $HOST_NUM
        sync_files $SCRIPT_DIR/../dependencies/kernel_module/cxl_ivpci.ko /root/cxl_ivpci.ko $HOST_NUM

        # sync dependencies
        echo "Sync dependencies..."
        sync_files /lib/x86_64-linux-gnu/libjemalloc.so.2 /lib/x86_64-linux-gnu/libjemalloc.so.2 $HOST_NUM
        sync_files /lib/x86_64-linux-gnu/libjemalloc.so.2 /root/libjemalloc.so.2 $HOST_NUM
        sync_files /lib/x86_64-linux-gnu/libglog.so.0  /lib/x86_64-linux-gnu/libglog.so.0 $HOST_NUM
        sync_files /lib/x86_64-linux-gnu/libgflags.so.2.2 /lib/x86_64-linux-gnu/libgflags.so.2.2 $HOST_NUM

        # setup the VM(s)
        echo "Loading kernel module..."
        for (( i=0; i < $HOST_NUM; ++i ))
        do
                ssh_command "rmmod cxl_ivpci 2>/dev/null" $i
                ssh_command "insmod ./cxl_ivpci.ko 2>/dev/null" $i
        done

        echo "Finished"
        exit 0
else
        print_usage
        exit -1
fi
