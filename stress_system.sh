#!/bin/bash
apt-get install sysstat
rm -f *.tmp
# source ../bin/checklist.sh
sync
echo 3 >/proc/sys/vm/drop_caches
if [ $# -lt 1 ];then
	echo "Usage: $0 <hdd_num>"
	exit 1
fi
cpucore=`cat /proc/cpuinfo |grep -i processor|wc -l`
mem=`cat /proc/meminfo |grep -i memtotal|awk '{print $2}'`
mem=` expr $mem / 1024 / 1024`
mem=${mem}

rtime=120
stime=15
mkdir "/stress_system_"$(date +%Y%m%d%H%M)
log_dir=`pwd`"/stress_system_"`date +%Y%m%d%H%M`

mkdir $log_dir 2>/dev/null

rm -f *.tmp
for disk in `lsscsi |grep -v sda|awk -F " " '{print $NF}'|grep "^/dev/"`
do
	echo "${disk}=2" >>iodepth.tmp
done
rm -f ../bin/fio

if [ -e ../bin/systeminfo.sh ]; then
	../bin/systeminfo.sh $log_dir $((rtime*3600))
fi
determine_iodepht()
{
	for i in {1..10}
	do
		while read disk
		do
			io_depth=`cat iodepth.tmp|grep $disk|awk -F "=" '{print $2}'`
			disk=`echo $disk|awk -F "=" '{print $1}'`
			../bin/fio --name=PR_IO_Test --rw=randread --direct=1 --time_based --ioengine=libaio --runtime=30s --filename=$disk --rwmixread=70 --bs=16k --iodepth=${io_depth} --minimal >fio.tmp
			rlat=`tail -n1 fio.tmp| awk -F ";" '{printf "%d\n",$40/1000}'`
			wlat=`tail -n1 fio.tmp| awk -F ";" '{printf "%d\n",$81/1000}'`
			if [ $((rlat*7+wlat*3)) -lt 200 ]; then
				io_depth_new=$((io_depth*2))
				diskname=`basename $disk`
				sed -i "s/${diskname}=$io_depth/${diskname}=${io_depth_new}/g" iodepth.tmp
			fi
		done <iodepth.tmp
		sleep $stime
	done
}

echo "This test will take $rtime hours."
if [ -e iodepth.tmp ]; then
	echo "All data on below disk will be destroyed!"
	cat iodepth.tmp|awk -F "=" '{print $1}'
	echo -n "Do you want to continue? [y|n]:"
	if [ ! `echo $*|grep "\-y"` ]; then
		read ans
		if [ "$ans" != "y" ]; then
			exit 0
		fi
	fi
	determine_iodepht
fi

echo `date`": System stress testing"
if [ -e iodepth.tmp ]; then
	while read disk
	do
		io_depth=`cat iodepth.tmp|grep $disk|awk -F "=" '{print $2}'`
		disk=`echo $disk|awk -F "=" '{print $1}'`
		echo "Start IO press for $disk!"
		../bin/fio --name=PR_IO_Test --rw=randread --direct=1 --time_based --ioengine=libaio --runtime=${rtime}h --filename=$disk --rwmixread=70 --bs=16k --iodepth=${io_depth} --minimal >/dev/null &
	done <iodepth.tmp
fi
../bin/stress --cpu $cpucore --vm $mem --vm-bytes 1G --hdd $1 --io $cpucore -t ${rtime}h

echo `date`": Peak rest testing"
for i in {1..21600}
do
	if [ -e iodepth.tmp ]; then
		while read disk
		do
			io_depth=`cat iodepth.tmp|grep $disk|awk -F "=" '{print $2}'`
			disk=`echo $disk|awk -F "=" '{print $1}'`
			echo "Start IO press for $disk!"
			../bin/fio --name=PR_IO_Test --rw=randread --direct=1 --time_based --ioengine=libaio --runtime=4 --filename=$disk --rwmixread=70 --bs=16k --iodepth=${io_depth} --minimal >/dev/null &
		done <iodepth.tmp
	fi
	../bin/stress --cpu $cpucore --vm $mem --vm-bytes 1G --hdd $1 --io $cpucore -t 4s
	sleep $stime
done

dmesg >$log_dir/dmesg.log
rm -f *.tmp
pkill mpstat
pkill iostat
pkill free
pkill sar