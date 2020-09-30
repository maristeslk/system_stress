#/bin/bash
apt-get install lsscsi sysstat
result_dir=/root/sysinfo_result
mkdir -p $result_dir
CPUMODEL=`grep "model name" /proc/cpuinfo | sort -u | tr -s ' ' | awk 'BEGIN{FS=": "} {print $2}'|cut -d " " -f 4`
NUMSOCK=`grep 'physical id' /proc/cpuinfo | sort -u | wc -l`
if [ $NUMSOCK -eq 0 ]; then
	NUMSOCK=`grep 'model name' /proc/cpuinfo| wc -l`
fi
dmidecode -t 0,2,17 > dmiinfo
DIMMNUM=`grep -i -A16 "memory device$" dmiinfo | grep -c 'Size: [0-9]'`
DIMMSIZE=`grep -i -A16 "memory device$" dmiinfo | grep -m 1 'Size: [0-9]' | awk '{print $2/1024}'`
DIMMTYPE=`grep -i -A16 "memory device$" dmiinfo | grep -m 1 'Type:' | awk 'BEGIN{FS=": "} {print $2}'`
DIMMSPEED=`grep -m 1 'Speed' dmiinfo | awk '{print $2}'`
DIMMPART=`grep -m 1 'Part Number: [[:alnum:]]' dmiinfo | awk '{print $3}'`
rm -f dmiinfo
echo "----------System----------" >${result_dir}/sysinfo.log
dmidecode -t system >>${result_dir}/sysinfo.log
echo "----------Kernel----------" >>${result_dir}/sysinfo.log
uname -a >>${result_dir}/sysinfo.log
echo "" >>${result_dir}/sysinfo.log
echo "----------CPU----------" >>${result_dir}/sysinfo.log
echo "CPU: $CPUMODEL CPU Socket: $NUMSOCK" >>${result_dir}/sysinfo.log
echo "" >>${result_dir}/sysinfo.log
echo "----------Memory----------" >>${result_dir}/sysinfo.log
echo "Memory Size: ${DIMMSIZE}GB, Memory Number: ${DIMMNUM}, Memory Type: ${DIMMTYPE}, Memory Speed: ${DIMMSPEED}, PART Number: ${DIMMPART}" >>${result_dir}/sysinfo.log
echo "" >>${result_dir}/sysinfo.log
echo "----------HBA/RAID Card----------" >>${result_dir}/sysinfo.log
lspci|grep -i sas >>${result_dir}/sysinfo.log
hba=`cat /proc/interrupts |grep sas|awk -F " " '{print $NF}'|awk -F "-" '{print $1}'|uniq`
for sas in $hba
do
		msix=`cat /proc/interrupts |grep sas|awk -F " " '{print $NF}'|awk -F "-" '{print $1}'|grep $sas|wc -l`
		echo "$sas MSI-X:${msix}" >>${result_dir}/sysinfo.log
done
echo "" >>${result_dir}/sysinfo.log
echo "----------NIC----------" >>${result_dir}/sysinfo.log
lspci|grep -i eth >>${result_dir}/sysinfo.log
eth=`sar -n DEV 1 1|awk -F " " '{print $2}'|grep -i eth|sort -u`
for nic in $eth
do
		bus=`ethtool -i $nic|grep bus-info|awk -F ":" '{print $3":"$4}'`
		msi=` lspci -vvv -s $bus|grep "MSI-X"|awk -F " " '{print $5}'|awk -F "=" '{print $2}'`
		if lspci -vvv -s $bus |grep -i "IOV" >/dev/null; then
			vfs=`lspci -vvv -s $bus|grep VFs|awk -F " " '{print $6}'`
			sriov="YES, VFs:$vfs"
		else
			sriov="NO"
		fi
		echo "$nic, $bus, MSI-X:$msi, Support SRIOV:$sriov" >>${result_dir}/sysinfo.log
		ethtool -i $nic >>${result_dir}/sysinfo.log
done

echo "" >>${result_dir}/sysinfo.log
echo "----------Logical Disk----------" >>${result_dir}/sysinfo.log
fdisk -l 2>/dev/null >>${result_dir}/sysinfo.log
echo "" >>${result_dir}/sysinfo.log
echo "----------Phisycal/Virtual Disks----------" >>${result_dir}/sysinfo.log
lsscsi >>${result_dir}/sysinfo.log
echo "" >>${result_dir}/sysinfo.log