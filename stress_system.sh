#!/bin/bash



# rm -f *.tmp
# sync
# echo 3 >/proc/sys/vm/drop_caches
# if [ $# -lt 1 ];then
# 	echo "Usage: $0 <hdd_num>"
# 	exit 1
# fi



log_dir=`pwd`"/stress_system_"`date +%Y%m%d%H%M`

mkdir -p $log_dir
cpucore=`cat /proc/cpuinfo |grep -i processor|wc -l`
mem=`cat /proc/meminfo |grep -i memtotal|awk '{print $2}'`
mem=` expr $mem / 1024 / 1024`
mem=${mem}
# rm -f *.tmp
function install (){
apt-get -y update
apt-get install -y sysstat lsscsi libaio-dev binutils

wget https://agora-devops-public-2.oss-cn-beijing.aliyuncs.com/Stress-testing/bin/fio_3.14 -O /usr/bin/fio
chmod +x /usr/bin/fio
wget https://agora-devops-public-2.oss-cn-beijing.aliyuncs.com/Stress-testing/bin/stress -O /usr/bin/stress
chmod +x /usr/bin/stress
wget https://agora-devops-public-2.oss-cn-beijing.aliyuncs.com/Stress-testing/bin/memtester -O /usr/bin/memtester
chmod +x /usr/bin/memtester

chmod +x systeminfo.sh

}

function test_start(){
	rm -rf *.tmp

	if [ ! -n "$system_disk" ];then
		for disk in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$")
			do
				disk=${disk#/dev/}
				size=$(parted -l |grep "Disk "  |grep $disk |awk '{print $3}'|head -n1| grep -oE "[0-9]{1,}")
				if [ $size -lt  600 ];then
					system_disk=${disk} 
				fi

			done
	fi
	hdd_num=$(lsscsi |grep -v ${system_disk}|awk -F " " '{print $NF}'|grep "^/dev/"|wc -l)
	rtime=1
	stime=15

	for disk in `lsscsi |grep -v sda |awk -F " " '{print $NF}'|grep "^/dev/"`
	do
		echo "${disk}=2" >>iodepth.tmp
	done
	mkdir $log_dir 2>/dev/null
	# determine_iodepth()
	# {
	# 	for i in {1..10}
	# 	do
	# 		while read disk
	# 		do
	# 			io_depth=`cat iodepth.tmp|grep $disk|awk -F "=" '{print $2}'`
	# 			disk=`echo $disk|awk -F "=" '{print $1}'`
	# 			/usr/bin/fio --name=PR_IO_Test --rw=randread --direct=1 --time_based --ioengine=libaio --runtime=30s --filename=$disk --rwmixread=70 --bs=16k --iodepth=${io_depth} --minimal >fio.tmp
	# 			rlat=`tail -n1 fio.tmp| awk -F ";" '{printf "%d\n",$40/1000}'`
	# 			wlat=`tail -n1 fio.tmp| awk -F ";" '{printf "%d\n",$81/1000}'`
	# 			if [ $((rlat*7+wlat*3)) -lt 200 ]; then
	# 				io_depth_new=$((io_depth*2))
	# 				diskname=`basename $disk`
	# 				sed -i "s/${diskname}=$io_depth/${diskname}=${io_depth_new}/g" iodepth.tmp
	# 			fi
	# 		done <iodepth.tmp
	# 		sleep $stime
	# 	done
	# }

	# echo "This test will take $rtime hours."
	# if [ -e iodepth.tmp ]; then
	# 	echo "All data on below disk will be destroyed!"
	# 	cat iodepth.tmp|awk -F "=" '{print $1}'
	# 	echo -n "Do you want to continue? [y|n]:"
	# 	if [ ! `echo $*|grep "\-y"` ]; then
	# 		read ans
	# 		if [ "$ans" != "y" ]; then
	# 			exit 0
	# 		fi
	# 	fi
	# 	determine_iodepth
	# fi




}

function stress_test(){

	# echo `date`": System stress testing"
	# if [ -e iodepth.tmp ]; then
	# 	while read disk
	# 	do
	# 		io_depth=`cat iodepth.tmp|grep $disk|awk -F "=" '{print $2}'`
	# 		disk=`echo $disk|awk -F "=" '{print $1}'`
	# 		echo "Start IO press for $disk!"
	# 		/usr/bin/fio --name=PR_IO_Test --rw=randread --direct=1 --time_based --ioengine=libaio --runtime=${rtime}h --filename=$disk --rwmixread=70 --bs=16k --iodepth=${io_depth} --minimal >/dev/null &
	# 	done <iodepth.tmp
	# fi
	# /usr/bin/stress --cpu $cpucore --vm $mem --vm-bytes 1G --hdd ${hdd_num} --io $cpucore -t ${rtime}h
	if [ ! -n "$system_disk" ];then
		for disk in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$")
			do
				disk=${disk#/dev/}
				size=$(parted -l |grep "Disk "  |grep $disk |awk '{print $3}'|head -n1| grep -oE "[0-9]{1,}")
				if [ $size -lt  600 ];then
					system_disk=${disk} 
				fi

			done
	fi
	hdd_num=$(lsscsi |grep -v ${system_disk}|awk -F " " '{print $NF}'|grep "^/dev/"|wc -l)
	rtime=1
	stime=15

	for disk in `lsscsi |grep -v sda |awk -F " " '{print $NF}'|grep "^/dev/"`
	do
		echo "${disk}=2" >>iodepth.tmp
	done
	mkdir $log_dir 2>/dev/null
	echo `date`": Peak rest testing"
	for i in {1..21600}
	do
		if [ -e iodepth.tmp ]; then
			while read disk
			do
				io_depth=`cat iodepth.tmp|grep $disk|awk -F "=" '{print $2}'`
				disk=`echo $disk|awk -F "=" '{print $1}'`
				echo "Start IO press for $disk!"
				/usr/bin/fio --name=PR_IO_Test --rw=randread --direct=1 --time_based --ioengine=libaio --runtime=4 --filename=$disk --rwmixread=70 --bs=16k --iodepth=${io_depth} --minimal >/dev/null &
			done <iodepth.tmp
		fi
		/usr/bin/stress --cpu $cpucore --vm $mem --vm-bytes 1G --hdd ${hdd_num} --io $cpucore -t 4s
		sleep $stime
	done

	dmesg >$log_dir/dmesg.log
	rm -f *.tmp
	pkill mpstat
	pkill iostat
	pkill free
	pkill sar

}

function memory_test(){

	n=3600

	echo `date`": Start stress memory."|tee -a $log_dir/memtester_run.log
	if [ -e systeminfo.sh ]; then
		./systeminfo.sh  $log_dir $((rwmixread_arr_num*ttime))
	fi
	mem=`cat /proc/meminfo |grep -i memtotal|awk '{print $2}'`
	mem=` expr $mem / 1024`
	if [ $mem -gt 2048 ]; then
		mem=` expr $mem / 1024 - 1`
		mem=${mem}"G"
	else
		mem=` expr $mem - 512`
		mem=${mem}"M"
	fi

	/usr/bin/memtester "$mem" >memtester_run.tmp &
	while [ $n -gt 0 ]
	do
		sleep 6
		strings memtester_run.tmp >>$log_dir/memtester_run.log
		echo "" >memtester_run.tmp
		n=$((n-1))
	done
	pkill memtester
	echo `date`": End stress memory."|tee -a $log_dir/memtester_run.log
	rm -f memtester_run.tmp
	pkill mpstat
	pkill iostat
	pkill free
	pkill sar
}
$@