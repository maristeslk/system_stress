    #!/bin/bash

        args_temp=$(getopt -o m:s: -- "$@")
        test_cmd_fail_exit="Use $0 [-c|-o var]"
        eval set -- "$args_temp"
        while true; do
            case $1 in

            -m) 
                mode=$2
                shift
                ;;
            -s)
                system_disk=$2
                shift
                ;;        
            --)
                shift
                break
                ;;
            *)
                echo_exit='Internal error'
                echo $echo_exit
                exit 0
                ;;
            esac
            shift
        done

        if [ ! -n "$system_disk" ];then
            for disk in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$")
            do
                disk=${disk#/dev/}
                size=$(parted -l |grep "Disk "  |grep $disk |awk '{print $3}'|head -n1| grep -oE "[0-9]{1,}")
                if [ $size -lt  800 ];then
                    system_disk=${disk} 
                fi

            done

        fi


        FIO_CMD='/usr/bin/fio'
        DISK_COUNT=$(ls /dev/sd* | grep -E 'sd[a-z]$'|grep -v ${system_disk}| wc -l)
        echo $system_disk

        function install()
        {   apt-get upadte 
            apt-get -y install jq libaio-dev 
            wget https://agora-devops-public-2.oss-cn-beijing.aliyuncs.com/Stress-testing/bin/fio_3.14 -O /usr/bin/fio
            chmod +x /usr/bin/fio
        

        }

        function env_init(){
            
            for i in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$"| grep -v "/dev/${system_disk}");do mkfs.ext4  -F $i ;done
            
            i=1;for disk  in $(seq 1 ${DISK_COUNT});do mkdir -p /data/$i/test;let i=i+1;done
            i=1;for disk in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$"| grep -v "/dev/${system_disk}");do mount $disk /data/$i;let i=i+1 ;done

        }





        #测试单盘 随机读 随机写 顺序读 顺序写 顺序混合读 顺序混合写 顺序读写 随机读写
        #测试所有盘 随机读 随机写 顺序读 顺序写 顺序混合读 顺序混合写 顺序读写 随机读写
        #随机 --direct=1 
        #顺序 iodepth=32 iodepth=1 block_size=128k iodepth=32 numjob=1
        #混合读写 --rwmixread=70

        function fio_nossd_test(){
            echo "start $type test"
            #顺序读 顺序写 顺序读写 默认配置
            if [ "$type" == "write" ]  || [ "$type" == "read" ];then
                size='100G'
                block_size="128k"
                iodepth="32"
                direct=''
                numjobs='1'
                norandommap=''
                randrepeat=''
                rwmixread=''

            elif [ "$type" == "rw" ];then
                size='50G'
                block_size="128k"
                iodepth="32"
                direct=''
                numjobs='1'
                norandommap=''
                randrepeat=''
                rwmixread="--rwmixread=70"

            elif [ "$type" == "randwrite" ] || [ "$type" == "randread" ];then
                size='5G'
                block_size="4k"
                iodepth="32"
                direct="--direct=1"
                numjobs='4'
                norandommap="--norandommap"
                randrepeat="--randrepeat=0"
                rwmixread=''

            elif [ "$type" == "randrw" ];then
                size='5G'
                block_size="4k"
                iodepth="32"
                direct="--direct=1"
                numjobs='4'
                norandommap="--norandommap"
                randrepeat="--randrepeat=0"
                rwmixread="--rwmixread=70"

            elif [ "$type" == "kafka" ];then

                size='200G'
                type='write'
                block_size="4k"
                iodepth="32"
                direct=""
                numjobs='1'
                norandommap=''
                randrepeat=''
                rwmixread=''

            fi


            i=1
            for disk in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$" | grep -v ${system_disk})
            do      
                json_type=${type##*rand}
                
                disk=${disk#/dev/}
                output_filename="/tmp/${disk}_${type}_${block_size}_${iodepth}"

                # path=$(lsblk  | grep $disk | awk {'print $7'})
                path="/data/$i"
                mkdir -p $path/test
                ${FIO_CMD} --directory=$path/test ${direct}  --rw=${type} --refill_buffers ${norandommap} ${randrepeat} --ioengine=libaio --bs=${block_size} ${rwmixread}  --ramp_time=60 --iodepth=${iodepth} --numjobs=${numjobs}  --group_reporting --name=4ktestwrite$i --size=${size} --output-format=json -output=$output_filename &
                let i=i+1

                # if [ ${check_read} == 1 ];then
                
                #     echo  disk_${type}_read_throughput="$(cat $output_filename |jq ."jobs[0].read.bw")" >> /tmp/$disk_result

                #     eval disk_${type}_read_iops="$(cat $output_filename |jq ."jobs[0].read.iops")" >> /tmp/$disk_result
                #     eval disk_${type}_read_throughput="$(cat $output_filename |jq ."jobs[0].write.bw")" >> /tmp/$disk_result
                #     eval disk_${type}_read_iops="$(cat $output_filename |jq ."jobs[0].write.iops")" >> /tmp/$disk_result
                # else 

                #     eval disk_${type}_throughput="$(cat $output_filename |jq ."jobs[0].$json_type}}.bw")" >> /tmp/$disk_result
                #     eval disk_${type}_iops="$(cat $output_filename |jq ."jobs[0].${json_type}.iops")"       >> /tmp/$disk_result
                    
                # fi

                # let i=i+1

            done


        }
        function wait_finish()
        {

            while [ 1 ] ##waiting for finish
                do
                    sleep 2
                    fios=`ps -ef|grep numjobs|grep -v grep|wc -l`
                    if [ $fios -eq 0 ]; then
                        break
                    fi
                done
        }

        function check_data(){

            rm -rf /tmp/*_result
            #查看检查并发的写入数据

            for disk in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$" | grep -v ${system_disk})
            do
                disk=${disk#/dev/}
                
                for result_file in $(ls /tmp/ |grep $disk)
                    do
                        
                        mode=$(echo $result_file | cut -d '_' -f 2)
                        mode=${mode#rand}
                        if [ "$mode" == 'rw' ];then
            
                            echo  ${result_file}-read_throughput="$(cat /tmp/$result_file |jq ."jobs[0].read.bw")" >> /tmp/${disk}_result
                            echo  ${result_file}-read_iops="$(cat /tmp/$result_file |jq ."jobs[0].read.iops"| cut -d '.' -f 1)" >> /tmp/${disk}_result
                            echo  ${result_file}-write_throughput="$(cat /tmp/$result_file |jq ."jobs[0].write.bw")" >> /tmp/${disk}_result
                            echo  ${result_file}-write_iops="$(cat /tmp/$result_file |jq ."jobs[0].write.iops" | cut -d '.' -f 1)" >> /tmp/${disk}_result

                            tmp_clat=$(cat /tmp/$result_file |jq ."jobs[0].read.clat_ns.percentile" | grep '99.990000' | awk '{print $2}' | cut -d ',' -f1  ) 
                            tmp_clat=$(echo "scale=0;${tmp_clat}/1000000"|bc)
                            echo  ${result_file}-read_clat="${tmp_clat}"  >> /tmp/${disk}_result

                            tmp_clat=$(cat /tmp/$result_file |jq ."jobs[0].write.clat_ns.percentile" | grep '99.990000' | awk '{print $2}' | cut -d ',' -f1  ) 
                            tmp_clat=$(echo "scale=0;${tmp_clat}/1000000"|bc)
                            echo  ${result_file}-write_clat="${tmp_clat}"  >> /tmp/${disk}_result                            


                        
                        elif [ "$mode" == 'read' ];then
                            echo  ${result_file}-read_throughput="$(cat /tmp/$result_file |jq ."jobs[0].read.bw")" >> /tmp/${disk}_result
                            echo  ${result_file}-read_iops="$(cat /tmp/$result_file |jq ."jobs[0].read.iops" | cut -d '.' -f 1)" >> /tmp/${disk}_result

                            tmp_clat=$(cat /tmp/$result_file |jq ."jobs[0].read.clat_ns.percentile" | grep '99.990000' | awk '{print $2}' | cut -d ',' -f1  ) 
                            tmp_clat=$(echo "scale=0;${tmp_clat}/1000000"|bc)
                            echo  ${result_file}-read_clat="${tmp_clat}"  >> /tmp/${disk}_result

                        elif [ "$mode" == 'write' ];then
                            echo  ${result_file}-write_throughput="$(cat /tmp/$result_file |jq ."jobs[0].write.bw")" >> /tmp/${disk}_result
                            echo  ${result_file}-write_iops="$(cat /tmp/$result_file |jq ."jobs[0].write.iops" | cut -d '.' -f 1)" >> /tmp/${disk}_result
                            
                            tmp_clat=$(cat /tmp/$result_file |jq ."jobs[0].write.clat_ns.percentile" | grep '99.990000' | awk '{print $2}' | cut -d ',' -f1  ) 
                            tmp_clat=$(echo "scale=0;${tmp_clat}/1000000"|bc)
                            echo  ${result_file}-write_clat="${tmp_clat}"  >> /tmp/${disk}_result  

                        fi
                    done

            done

            #清除上一次数据 
            rm -rf /root/fio_fin_result
            echo "type,base_line,sum,avg,diff,max,min,status" >> /root/fio_fin_result

            check_list='write_128k_32-write_throughput'
            limit='220000'
            check_result

            check_list='write_4k_32-write_throughput'
            limit='220000'
            check_result
                        
            check_list='randwrite_4k_32-write_throughput'
            limit='8000'
            check_result
            
            check_list='randread_4k_32-read_throughput'
            limit='1500'
            check_result

            check_list='rw_128k_32-write_throughput'
            limit='48000'
            check_result

            check_list='rw_128k_32-read_throughput'
            limit='140000'
            check_result
            
            check_list='randrw_4k_32-write_throughput'
            limit='500'
            check_result 

            check_list='randrw_4k_32-read_throughput'
            limit='1100'
            check_result

            check_list='write_128k_32-write_clat'
            limit='100'
            check_result
            
            check_list='randwrite_4k_32-write_clat'
            limit='10000'
            check_result
            
            check_list='randread_4k_32-read_clat'
            limit='2000'
            check_result

            check_list='rw_128k_32-write_clat'
            limit='1200'
            check_result

            check_list='rw_128k_32-read_clat'
            limit='1200'
            check_result
            
            check_list='randrw_4k_32-write_clat'
            limit='5000'
            check_result 

            check_list='randrw_4k_32-read_clat'
            limit='5000'
            check_result		
            echo 'test_final'
        }

        function check_result(){
            i=0
            tmp_sum=0
            tmp_min=99999999999999
            tmp_max=0
            result_file='/tmp/sd*_result'
            # result_file='/root/result'

            for value in $(cat $result_file |  cut -d '_' -f 2-100 |grep -E "^${check_list}" )

            do 
                
                value=$(echo $value | cut -d '=' -f 2)
                [ $tmp_max -lt $value ] && tmp_max=$value
                [ $tmp_min -gt $value ] && tmp_min=$value
                let tmp_sum=${tmp_sum}+${value}

            done

            let fin_sum=${tmp_sum}
            let fin_avg=${fin_sum}/${DISK_COUNT}
            let diff=$limit-$fin_avg

            echo ${check_list} | grep 'clat'
            if [ $? == 0 ];then

                if [ $fin_avg -gt $limit ];then

                    echo "$check_list,$limit,$fin_sum,$fin_avg,$diff,$tmp_max,$tmp_min,bad"  >> /root/fio_fin_result
                else
                    echo "$check_list,$limit,$fin_sum,$fin_avg,$diff,$tmp_max,$tmp_min,good"  >> /root/fio_fin_result
                fi                
            
            else

                if [ $fin_avg -lt $limit ];then
                    echo "$check_list,$limit,$fin_sum,$fin_avg,$diff,$tmp_max,$tmp_min,bad"  >> /root/fio_fin_result
                else
                    echo "$check_list,$limit,$fin_sum,$fin_avg,$diff,$tmp_max,$tmp_min,good"  >> /root/fio_fin_result
                fi
            fi


        }
        
        function test_start(){

            if [ "${mode}" == 'all' ];then

                type='write'
                fio_nossd_test
                wait_finish
                # type='read'
                # fio_nossd_test
                # wait_finish
                type='rw'
                fio_nossd_test
                wait_finish
                type='randwrite'
                fio_nossd_test  
                wait_finish
                type='randread'
                fio_nossd_test
                wait_finish
                type='randrw'
                fio_nossd_test
                wait_finish
            else 
                type=${mode}
                fio_nossd_test
                wait_finish
            fi


            #删除测试产生的垃圾
            for i in $(seq 1 ${DISK_COUNT})
            do
                rm -rf /data/$i/test
            done
            #汇总数据
            check_data
            
        }

        $@