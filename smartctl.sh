
#!/bin/bash

HOSTNAME=$(hostname)
vendor=`dmidecode -s system-manufacturer | tail -n 1`
system_version=$(cat /etc/lsb-release  | grep DISTRIB_RELEASE | cut -d '=' -f 2)
TYPE="direct"
#get vendor ipmi info
# case $vendor in
#  *Powerleader*)
#         TYPE="direct"
#         ;;
#  *H3C*)
#         TYPE="direct"
#         ;;
#  *Lenovo*)
#         TYPE="direct"
#         ;;
#  *Huawei*)
#         TYPE="direct"
#         ;;
#  *Dell*)
#         TYPE="megaraid"
#         ;;
#  *HP*)
#         TYPE="cciss"
#         ;;
#  *Inspur*)
#         TYPE="megaraid"
#         ;;
#  *Supermicro*)
#         TYPE="megaraid"
#         ;;
#  *Cisco*)
#         TYPE="direct"
#         ;;
#  *)
#         echo "not match machine vendor"
#         exit 1
#         ;;
# esac
echo $HOSTNAME 


function smartd_install(){
    if  [ $system_version == '18.04' ];then
        apt-get -y install smartmontools  lsscsi
        #更新drivedb.h
        wget https://raw.githubusercontent.com/smartmontools/smartmontools/master/smartmontools/drivedb.h -O /var/lib/smartmontools/drivedb/drivedb.h
        #配置后台运行并且每隔21600秒读取一次smart信息
        sed -i 's/#start_smartd=yes/start_smartd=yes/' /etc/default/smartmontools
        sed -i 's/#smartd_opts="--interval=1800"/smartd_opts="--interval=21600"/' /etc/default/smartmontools
        #重定向日志 smartd依赖rsyslog 定义local3放smart的日志
        sed -i 's/\$smartd_opts$/\$smartd_opts -l local3/' /lib/systemd/system/smartd.service
        systemctl daemon-reload 
        echo "local3.* /var/log/smartd.log" >> /etc/rsyslog.d/50-smartd.conf 
        systemctl restart rsyslog
        #清理原始磁盘序列号索引 disk_sn.txt 默认只会生成一次 如果换盘了需要手动跑一下disk_sn_update
        
        systemctl restart smartd    
    elif [ $system_version == '14.04' ];then
        apt-get -y install smartmontools
        #配置后台运行并且每隔21600秒读取一次smart信息
        sed -i 's/#start_smartd=yes/start_smartd=yes/' /etc/default/smartmontools
        sed -i 's/#smartd_opts="--interval=1800"/smartd_opts="--interval=21600"/' /etc/default/smartmontools
        #清理原始磁盘序列号索引 disk_sn.txt 默认只会生成一次 如果换盘了需要手动跑一下disk_sn_update

    fi

    #生产配置文件
    rm -rf  /var/lib/smartmontools/disk_sn.txt
    cp /etc/smartd.conf /etc/smartd.conf.bak
    echo '' > /etc/smartd.conf
    
    smartctl --scan | grep "megaraid"
    if [ $? == 0 ];then
        TYPE="megaraid"
    fi
    smartctl --scan | grep "cciss"
    if [ $? == 0 ];then
        TYPE="cciss"
    fi

    if [ "$TYPE" == "megaraid" ];then

            for SLOT in  $(smartctl --scan  | grep 'megaraid' | awk {'print $3'} |cut -d ',' -f 2)
                do  
                    #sda的兼容性更好
                    SN=$(smartctl -d megaraid,$SLOT  -a /dev/sda | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                        if [ "$SN" == "" ];then
                            check_support=$(smartctl  -a $DISK_DRIVE | grep -o 'Unavailable' )
                            #兼容超微 系统盘没有插在megaraid卡上的情况
                            if [ "$check_support" == "Unavailable" ] && [ $vendor == "Supermicro" ];then
                                SN=$(smartctl  -a /dev/sdm | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                            else
                                SN=$(smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
        
                            fi
                        fi
                        # echo "/dev/bus/0 -d megaraid,$SLOT -l error -l selftest -t -I 190 -S on -s (S/../.././02)" >> /etc/smartd.conf
                        
                        echo "$SLOT;$SN;" >> /var/lib/smartmontools/disk_sn.txt
                done
    elif [ "$TYPE" == "direct" ];then
            for DISK_DRIVE in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$")
                    do
                            SN=$(smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                            echo "$DISK_DRIVE;$SN;" >> /var/lib/smartmontools/disk_sn.txt

                    done
            
    fi
    echo "DEVICESCAN -H -l error -l selftest -t -I 190 -n never -S on -s (S/../.././02)" >> /etc/smartd.conf

    if  [ $system_version == '18.04' ];then
        systemctl restart smartd
    else
        service smartmontools restart
    fi
    #配置定时任务
    
}

function disk_sn_update(){
    #生产配置文件
    rm -rf  /var/lib/smartmontools/disk_sn.txt
    cp /etc/smartd.conf /etc/smartd.conf.bak
    echo '' > /etc/smartd.conf
    
    smartctl --scan | grep "megaraid"
    if [ $? == 0 ];then
        TYPE="megaraid"
    fi
    smartctl --scan | grep "cciss"
    if [ $? == 0 ];then
        TYPE="cciss"
    fi

    if [ "$TYPE" == "megaraid" ];then
            for SLOT in $(smartctl --scan  | grep 'megaraid' | awk {'print $3'} |cut -d ',' -f 2)
                do  
                    #sda的兼容性更好
                    SN=$(smartctl -d megaraid,$SLOT  -a /dev/sda | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                        if [ "$SN" == "" ];then
                            check_support=$(smartctl  -a $DISK_DRIVE | grep -o 'Unavailable' )
                            #兼容超微 系统盘没有插在megaraid卡上的情况
                            if [ "$check_support" == "Unavailable" ] && [ $vendor == "Supermicro" ];then
                                SN=$(smartctl  -a /dev/sdm | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                            else
                                SN=$(smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
        
                            fi
                        fi
                        # echo "/dev/bus/0 -d megaraid,$SLOT -l error -l selftest -t -I 190 -S on -s (S/../.././02)" >> /etc/smartd.conf
                        
                        echo "$SLOT;$SN;" >> /var/lib/smartmontools/disk_sn.txt
                done
    elif [ "$TYPE" == "direct" ];then
            for DISK_DRIVE in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$")
                    do
                            SN=$(smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                            echo "$DISK_DRIVE;$SN;" >> /var/lib/smartmontools/disk_sn.txt

                    done
            
    fi
    echo "DEVICESCAN -H -l error -l selftest -t -I 190 -n never -S on -s (S/../.././02)" >> /etc/smartd.conf

    if  [ $system_version == '18.04' ];then
        systemctl restart smartd
    else
        service smartmontools restart
    fi
}


function update_info(){

    smartctl --scan | grep "megaraid"
    if [ $? == 0 ];then
        TYPE="megaraid"
    fi
    smartctl --scan | grep "cciss"
    if [ $? == 0 ];then
        TYPE="cciss"
    fi

    if [ "$TYPE" == "megaraid" ];then

            for info  in $( cat /var/lib/smartmontools/disk_sn.txt )
                    do
                            SLOT_NUM=$(echo $info| cut -d ';' -f 1)
                            SN=$(echo $info| cut -d ';' -f 2)
                            file_path=$(ls /var/lib/smartmontools/ | grep attrlog |grep $SN)
                            file_path="/var/lib/smartmontools/${file_path}"
                            smart_health=$(smartctl -d megaraid,$SLOT_NUM  -H  "${disk}" | grep -E "^SMART*"  | cut -d ':' -f 2 | cut -d "[" -f 1 |tr ' ' '_')
                            smart_health=${smart_health#"_"}
                            smart_health=${smart_health%"_"}
                            OLD_IFS=$IFS;

                            TIME=$(tail -n1 ${file_path}  | cut -d ';' -f1)
                            for ATTR in $(tail -n1  ${file_path} |  grep -oE '[a-z]{1,}-[a-z]{1,}-[a-z]{1,}-[a-z]{1,};[0-9]{1,3}')
                                    do
                                            ATTR_NAME=$(echo $ATTR| cut -d ';' -f 1)
                                            ATTR_VALUE=$(echo $ATTR| cut -d ';' -f 2)
                                            if [ "$ATTR_NAME" == "read-total-unc-errors" ];then
                                                    RTUE="read_total_unc_errors:${ATTR_VALUE}"
                                            elif [ "$ATTR_NAME" == "write-total-unc-errors" ];then
                                                    WTUE="write-total-unc-errors:${ATTR_VALUE}"
                                            elif [ "$ATTR_NAME" == "write-corr-algorithm-invocations" ];then
                                                    WCAI="write_corr_algorithm_invocations:${ATTR_VALUE}"
                                            elif [ "$ATTR_NAME" == "read-corr-algorithm-invocations" ];then
                                                    RCAI="read_corr_algorithm_invocations:${ATTR_VALUE}"
                                            fi
                                    done
                            echo $SLOT_NUM $SN $smart_health $RTUE $WTUE $WCAI $RCAI
            done
    fi


    if [ "$TYPE" == "direct" ];then

            for info  in $( cat /var/lib/smartmontools/disk_sn.txt )
                    do
                            disk=$(echo $info| cut -d ';' -f 1)
                            SN=$(echo $info| cut -d ';' -f 2)
                            smart_health=$(smartctl -H  "${disk}" | grep -E "^SMART*" | cut -d ':' -f 2 | cut -d "[" -f 1 |tr ' ' '_')
                            smart_health=${smart_health#"_"}
                            smart_health=${smart_health%"_"}
                            OLD_IFS=$IFS;
                            file_path=$(ls /var/lib/smartmontools/ | grep attrlog |grep $SN)
                            file_path="/var/lib/smartmontools/${file_path}"
                            if [ "$smart_health" = "OK" ] ||  [ "$smart_health" = "PASSED" ];then
                                :
                            else
                                smart_health=$(smartctl  -H  "${disk}" | grep -E "^SMART*"  | cut -d ':' -f 2  |  tr " " "_" | cut -d '[' -f 1 )
                                smart_health=${smart_health#"_"}
                                smart_health=${smart_health%"_"}
                            fi
                            TIME=$(tail -n1 ${file_path}  | cut -d ';' -f1)
                            if [ "$vendor" == "Lenovo" ];then
                                for ATTR in $(tail -n1  ${file_path} |  grep -oE '[a-z]{1,}-[a-z]{1,}-[a-z]{1,}-[a-z]{1,};[0-9]{1,3}')
                                    do
                                            ATTR_NAME=$(echo $ATTR| cut -d ';' -f 1)
                                            ATTR_VALUE=$(echo $ATTR| cut -d ';' -f 2)
                                            if [ "$ATTR_NAME" == "read-total-unc-errors" ];then
                                                    RTUE="read_total_unc_errors:${ATTR_VALUE}"
                                            elif [ "$ATTR_NAME" == "write-total-unc-errors" ];then
                                                    WTUE="write-total-unc-errors:${ATTR_VALUE}"
                                            elif [ "$ATTR_NAME" == "write-corr-algorithm-invocations" ];then
                                                    WCAI="write_corr_algorithm_invocations:${ATTR_VALUE}"
                                            elif [ "$ATTR_NAME" == "read-corr-algorithm-invocations" ];then
                                                    RCAI="read_corr_algorithm_invocations:${ATTR_VALUE}"
                                            fi
                                    done
                                echo $SLOT_NUM $SN $smart_health $RTUE $WTUE $WCAI $RCAI
                            else
                                for ATTR in $(tail -n1  ${file_path} | grep -oE '[0-9]{1,3};[0-9]{1,3};[0-9]{1,3}')
                                        do
                                                ATTR_ID=$(echo $ATTR| cut -d ';' -f 1)
                                                ATTR_VALUE=$(echo $ATTR| cut -d ';' -f 3)
                                                if [ "$ATTR_ID" == "5" ];then
                                                        ATTR_NUM_5="Reallocated_Sectors_Count:${ATTR_VALUE}"
                                                elif [ "$ATTR_ID" == "187" ];then
                                                        ATTR_NUM_187="Reported_Uncorrectable_Errors:${ATTR_VALUE}"
                                                elif [ "$ATTR_ID" == "189" ];then
                                                        ATTR_NUM_189="Offline_Uncorrectable_Sector_Count:${ATTR_VALUE}"
                                                fi
                                
                                        done
                                echo $SLOT_NUM $disk $SN $smart_health $ATTR_NUM_5 $ATTR_NUM_187 $ATTR_NUM_189
                            fi
            done
    fi

}
$@