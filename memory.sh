#!/bin/bash
wget https://agora-devops-public-2.oss-cn-beijing.aliyuncs.com/Stress-testing/bin/stream -O /usr/bin/stream
wget https://agora-devops-public-2.oss-cn-beijing.aliyuncs.com/Stress-testing/bin/stream_omp -O /usr/bin/stream_omp
rm -f mem_test.log 2>/dev/null
rm -f mem.csv 2>/dev/null
rm -f temp 2>/dev/null
mem=1024
stream()
{
	rm -f temp 2>/dev/null
	sync
	echo 3 >/proc/sys/vm/drop_caches
	sleep 1
	echo `date` |tee -a temp
	loop=10
	while [ $loop -gt 0 ]
	do
		echo "$loop"
		 $CMD >>temp
		loop=$((loop-1))
	done

	c1=`cat temp|grep "Copy:" | awk '{print $2}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.1f\n",sum/num}'`
	c2=`cat temp|grep "Copy:" | awk '{print $3}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c3=`cat temp|grep "Copy:" | awk '{print $4}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c4=`cat temp|grep "Copy:" | awk '{print $5}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	echo "Copy,$c1,$c2,$c3,$c4" >>mem.csv
	c1=`cat temp|grep "Scale:" | awk '{print $2}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.1f\n",sum/num}'`
	c2=`cat temp|grep "Scale:" | awk '{print $3}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c3=`cat temp|grep "Scale:" | awk '{print $4}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c4=`cat temp|grep "Scale:" | awk '{print $5}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	echo "Scale,$c1,$c2,$c3,$c4" >>mem.csv
	c1=`cat temp|grep "Add:" | awk '{print $2}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.1f\n",sum/num}'`
	c2=`cat temp|grep "Add:" | awk '{print $3}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c3=`cat temp|grep "Add:" | awk '{print $4}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c4=`cat temp|grep "Add:" | awk '{print $5}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	echo "Add,$c1,$c2,$c3,$c4" >>mem.csv
	c1=`cat temp|grep "Triad:" | awk '{print $2}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.1f\n",sum/num}'`
	c2=`cat temp|grep "Triad:" | awk '{print $3}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c3=`cat temp|grep "Triad:" | awk '{print $4}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	c4=`cat temp|grep "Triad:" | awk '{print $5}' | awk 'BEGIN{sum=0;num=0}{sum+=$1;num+=1}END{printf "%.4f\n",sum/num}'`
	echo "Triad,$c1,$c2,$c3,$c4" >>mem.csv
	cat temp>>mem_test.log
	rm -f temp 2>/dev/null
	echo `date`
}

CMD="/usr/bin/stream"
echo "Single thread" |tee -a mem.csv
echo "Function,Rate (MB/s),Avg time,Min time,Max time" >>mem.csv
stream
CMD="/usr/bin/stream_omp"
echo "" >>mem.csv
echo "Multi threads" |tee -a mem.csv
echo "Function,Rate (MB/s),Avg time,Min time,Max time" >>mem.csv
stream
echo "" >>mem.csv

# CMD="numactl --cpunodebind=0 --membind=0 /usr/bin/stream"
# echo "Single thread within the NUMA node" |tee -a mem.csv
# echo "Function,Rate (MB/s),Avg time,Min time,Max time" >>mem.csv
# stream
# echo "" >>mem.csv
# CMD="numactl --cpunodebind=0 --membind=1 /usr/bin/stream"
# echo "Single thread cross the NUMA node" |tee -a mem.csv
# echo "Function,Rate (MB/s),Avg time,Min time,Max time" >>mem.csv
# stream
# echo "" >>mem.csv

echo "Latency test,ns" |tee -a mem.csv
../bin/lat_mem_rd -N 1 -P 1 $mem 1024 2>&1 |grep -v stride|tee -a temp
cat temp>>mem_test.log
l1=`lscpu|grep "L1d cache:"|awk -F " " '{print $3}'|awk -F "K" '{print $1}'`
a1=$((l1/4))
a2=$((l1*3/4))
l2=`lscpu|grep "L2 cache:"|awk -F " " '{print $3}'|awk -F "K" '{print $1}'`
b1=$((l2/4))
b2=$((l1+l2-b1))
b1=$((b1+l1))
if lscpu|grep "L3 cache:"; then
	l3=`lscpu|grep "L3 cache:"|awk -F " " '{print $3}'|awk -F "K" '{print $1}'`
fi
if [ ! -z $l3 ]; then
	c1=$((l3/4))
	c2=$((l1+l2+l3-c1))
	c1=$((c1+l1+l2))
	m1=$((l3+l1+l2))
	m1=$((m1*2))
else
	m1=$((l1+l2))
	m1=$((m1*2))
fi
m2=$((mem*1000-1000))
l1_lat=0
l2_lat=0
l3_lat=0
m_lat=0
l1_count=0
l2_count=0
l3_count=0
m_count=0
sed -i /^$/d temp >/dev/null
sed -i /^0.000.*/d temp >/dev/null
while read csize lat
do
	csize=`echo "scale=0;$csize*1000"|bc`
	csize=`echo  $csize|awk -F "." '{print $1}'`
	lat=`echo "scale=0;$lat*1000"|bc`
	lat=`echo  $lat|awk -F "." '{print $1}'`
	if [ $csize -gt $a1 -a $csize -lt $a2 ]; then
		l1_lat=$((l1_lat+lat))
		l1_count=$((l1_count+1))
	elif [ $csize -gt $b1 -a $csize -lt $b2 ]; then
		l2_lat=$((l2_lat+lat))
		l2_count=$((l2_count+1))
	elif [ ! -z $l3 ] && [ $csize -gt $c1 -a $csize -lt $c2 ]; then
		l3_lat=$((l3_lat+lat))
		l3_count=$((l3_count+1))
	elif [ $csize -gt $m1 -a $csize -lt $m2 ]; then
		m_lat=$((m_lat+lat))
		m_count=$((m_count+1))
	fi
done < temp
l1_lat=$((l1_lat/l1_count))
l1_lat=`echo "scale=3;$l1_lat/1000"|bc`
echo "L1 Latency,$l1_lat" |tee -a mem.csv
l2_lat=$((l2_lat/l2_count))
l2_lat=`echo "scale=3;$l2_lat/1000"|bc`
echo "L2 Latency,$l2_lat" |tee -a mem.csv
if [ ! -z $l3 ]; then
	l3_lat=$((l3_lat/l3_count))
	l3_lat=`echo "scale=3;$l3_lat/1000"|bc`
	echo "L3 Latency,$l3_lat" |tee -a mem.csv
fi
m_lat=$((m_lat/m_count))
m_lat=`echo "scale=3;$m_lat/1000"|bc`
echo "Memory Latency,$m_lat" |tee -a mem.csv
rm -f temp 2>/dev/null
