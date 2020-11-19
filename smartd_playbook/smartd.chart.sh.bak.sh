# shellcheck shell=bash
# no need for shebang - this file is loaded from charts.d.plugin
# SPDX-License-Identifier: GPL-3.0-or-later

# netdata
# real-time performance and health monitoring, done right!
# (C) 2016 Costa Tsaousis <costa@tsaousis.gr>
#

# if this chart is called X.chart.sh, then all functions and global variables
# must start with X_



smartd_get() {
  # do all the work to collect / calculate the values
    rm -rf /opt/netdata/share/smart_info
    for info  in $( cat /opt/netdata/share/disk_sn.txt )
        do
                #获取磁盘 sn 
                DISK_TYPE=$(echo $info| cut -d ';' -f 1)
                SLOT_NUM=$(echo $info| cut -d ';' -f 2)
                DISK_DRIVE=$(echo $info| cut -d ';' -f 3)
                SN=$(echo $info| cut -d ';' -f 4)

                #根据raid类型获取健康状态
                if [ "$CONTROLL_TYPE" == "megaraid" ];then
                    smart_health=$(sudo smartctl -d megaraid,$SLOT_NUM  -H  "${DISK}" | grep -E "^SMART*"  | cut -d ':' -f 2 | cut -d "[" -f 1 |tr ' ' '_')
                elif  [ "$CONTROLL_TYPE" == "direct" ];then
                    smart_health=$(sudo smartctl -H  "${DISK}" | grep -E "^SMART*" | cut -d ':' -f 2 | cut -d "[" -f 1 |tr ' ' '_')
                fi

                OLD_IFS=$IFS;
                smart_health=${smart_health#"_"}
                smart_health=${smart_health%"_"}

                if [ "$smart_health" = "OK" ] ||  [ "$smart_health" = "PASSED" ];then
                    :
                else
                    smart_health=$(sudo smartctl  -H  "${DISK}" | grep -E "^SMART*"  | cut -d ':' -f 2  |  tr " " "_" | cut -d '[' -f 1 )
                    smart_health=${smart_health#"_"}
                    smart_health=${smart_health%"_"}
                fi
                # TIME="$(tail -n1 ${file_path}  | cut -d ';' -f1)"
                #nvme的磁盘不能通过csv获取
                if [ "$DISK_TYPE" != "nvme" ];then

                  #根据sn获取csv路径
                  file_path=$(ls /var/lib/smartmontools/ | grep attrlog |grep $SN)
                  file_path="/var/lib/smartmontools/${file_path}"
                  file_result=$(tail -n1  ${file_path} |  grep -oE '[a-z]{1,}-[a-z]{1,}-[a-z]{1,}-[a-z]{1,};[0-9]{1,3}')

                  if [ $? == 0 ]; then
                      attr_key='string'
                  else
                  #纯数字
                      attr_key='int'
                      file_result=$(tail -n1  ${file_path} | grep -oE '[0-9]{1,3};[0-9]{1,3};[0-9]{1,3}')
                  fi

                  SLOT_NUM=$( lsscsi | grep $DISK_DRIVE | awk '{print $1}')
                  SLOT_NUM=${SLOT_NUM#"["}
                  SLOT_NUM=${SLOT_NUM%"]"}
                  #循环每一个值
                  for ATTR in $file_result
                      do
                              ATTR_NAME=$(echo $ATTR| cut -d ';' -f 1)
                              if [ "$attr_key" == "int" ] && [ "$DISK_TYPE" == "sata" ];then

                                  ATTR_VALUE=$(echo $ATTR| cut -d ';' -f 3)
                                  if [ "$ATTR_NAME" == "5" ];then
                                          ATTR_NUM_5="Reallocated_Sectors_Count:${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "187" ];then
                                          ATTR_NUM_187="Reported_Uncorrectable_Errors:${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "197" ];then
                                          ATTR_NUM_197="Current_Pending_Sector:${ATTR_VALUE}"
                                  fi
    
                              elif  [ "$attr_key" == 'string'] && ["$DISK_TYPE" == "sas" ];then
                                  if [ "$ATTR_NAME" == "read-total-unc-errors" ];then
                                          RTUE="read_total_unc_errors:${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "write-total-unc-errors" ];then
                                          WTUE="write_total_unc-errors:${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "write-corr-algorithm-invocations" ];then
                                          WCAI="write_corr_algorithm_invocations:${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "read-corr-algorithm-invocations" ];then
                                          RCAI="read_corr_algorithm_invocations:${ATTR_VALUE}"
                                  fi
                              elif  [ "$attr_key" == "string" ] && ["$DISK_TYPE" == "sata" ];then
                                  :
                              elif  [ "$attr_key" == "int" ] && ["$DISK_TYPE" == "sas" ];then
                                  :
                              fi
                      done
                      if [ "$attr_key" == 'int' ] && [ "$DISK_TYPE" == "sata" ];then
                        echo "$DISK_TYPE,$SLOT_NUM,$DISK_DRIVE,$SN,$smart_health,$ATTR_NUM_5,$ATTR_NUM_187,$ATTR_NUM_197" >> /opt/netdata/share/smart_info
                        elif  [ "$attr_key" == "string" ] && [ "$DISK_TYPE" == "sas" ];then
                        echo "$DISK_TYPE,$SLOT_NUM,$DISK_DRIVE,$SN,$smart_health,$RTUE,$WTUE,$WCAI,$RCAI" >> /opt/netdata/share/smart_info
                        elif  [ "$attr_key" == "string" ] && [ "$DISK_TYPE" == "sata" ];then
                                :
                        elif  [ "$attr_key" == "int" ] && [ "$DISK_TYPE" == "sas" ];then
                                :
                      fi
                  else
                    media_and_data_integrity_errors=$(sudo smartctl -x  ${DISK}  | grep -i 'Media and Data Integrity Errors' | awk -F: '{print $2}' |sed s/[[:space:]]//g)
                    data_integ_errors="media_and_data_integrity_errors:${media_and_data_integrity_errors}"
                    error_information_log_entries=$(sudo smartctl -x  ${DISK}  | grep -i 'Error Information Log Entries' | awk -F: '{print $2}'|sed s/[[:space:]]//g)
                    error_infor_log_entries="error_information_log_entries:${error_information_log_entries}"
                    echo "$DISK_TYPE,$SLOT_NUM,$DISK_DRIVE,$SN,$smart_health,$data_integ_errors,$error_infor_log_entries" >> /opt/netdata/share/smart_info

                  fi
        done

  return 0
}

# _check is called once, to find out if this chart should be enabled or not
smartd_check() {
  # this should return:
  #  - 0 to enable the chart
  #  - 1 to disable the chart

  # check sudo smartctl 是否安装

  # require_cmd sudo smartctl && [ ! -d "/opt/netdata/share/disk_sn.txt" ] && return 0
  # require_cmd  smartctl && require_cmd lsscsi  && return 0
#   # check that we can collect data
#   smartd_get || return 1
return 0
}

# _create is called once, to create the charts
smartd_create() {


  rm -rf  /opt/netdata/share/disk_sn.txt
  if [ "$CONTROLL_TYPE" == "megaraid" ];then
      :
  elif [ "$CONTROLL_TYPE" == "direct" ];then
      #初版只满足直通的服务器

  for DISK_DRIVE in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$")
    do
            SN=$(sudo smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
            SLOT_NUM=$( lsscsi | grep $DISK_DRIVE | awk '{print $1}')
            SLOT_NUM=${SLOT_NUM#"["}
            SLOT_NUM=${SLOT_NUM%"]"}
            sudo smartctl  -a $DISK_DRIVE | grep -i 'SATA'
            if [ $? == 0 ];then
              DISK_TYPE='sata'
            else
              DISK_TYPE='sas'
            fi
            echo "$DISK_TYPE;$SLOT_NUM;$DISK_DRIVE;$SN" >> /opt/netdata/share/disk_sn.txt
    done

    #判断是否有nvme盘
    if [ "$IFNVME" == "1" ];then
      for DISK_DRIVE in $( ls /dev/nvme* | grep -E "/dev/nvme[0-9]$")
        do
                SN=$(sudo smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                SLOT_NUM=$( lspci |  grep -i 'nvme' | awk '{print $1}')
                DISK_TYPE='nvme'
                echo "$DISK_TYPE;$SLOT_NUM;$DISK_DRIVE;$SN" >> /opt/netdata/share/disk_sn.txt
        done 
    fi

  fi
    for info  in $( cat /opt/netdata/share/disk_sn.txt )
      do
        DISK=$(echo $info| cut -d ';' -f 3 | cut -d '/' -f 3)
        SN=$(echo $info| cut -d ';' -f 4)
        DISK_TYPE=$(echo $info| cut -d ';' -f 1)
      if [ "$DISK_TYPE" == "sata" ];then
  #CHART type.id         name    title                                    units [family [context [charttype [priority [update_every [options [plugin [module]]]]]]]]
#         cat << EOF
# CHART  smartd_${DISK} '' "smart_info on ${DISK}" "smart" "${DISK}" "status" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
# DIMENSION Reallocated_Sectors_Count 'Reallocated_Sectors_Count'  absolute 1 1
# DIMENSION Reported_Uncorrectable_Errors 'Reported_Uncorrectable_Errors' absolute 1 1
# DIMENSION Current_Pending_Sector 'Current_Pending_Sector' absolute 1 1
# EOF
        cat << EOF
CHART  smartd_${DISK}.status '' "smart_info on ${DISK}" "smart" "${DISK}" "disk" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION Reallocated_Sectors_Count 'Reallocated_Sectors_Count'  absolute 1 1
DIMENSION Reported_Uncorrectable_Errors 'Reported_Uncorrectable_Errors' absolute 1 1
DIMENSION Current_Pending_Sector 'Current_Pending_Sector' absolute 1 1
EOF
        elif [ "$DISK_TYPE" == "sas" ];then
        cat << EOF
CHART  smartd_${DISK}.status '' "smart_info on ${DISK}" "smart" "${DISK}" "disk" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION read_total_unc_errors 'read_total_unc_errors' absolute 1 1
DIMENSION write_total_unc-errors 'write_total_unc-errors' absolute 1 1
DIMENSION write_corr_algorithm_invocations 'write_corr_algorithm_invocations' absolute 1 1
DIMENSION read_corr_algorithm_invocations 'read_corr_algorithm_invocations' absolute 1 1
EOF
        elif [ "$DISK_TYPE" == "nvme" ];then
        cat << EOF
CHART  smartd_${DISK}.status '' "smart_info on ${DISK}" "smart" "${DISK}" "disk" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION media_and_data_integrity_errors 'media_and_data_integrity_errors' absolute 1 1
DIMENSION error_information_log_entries 'error_information_log_entries' absolute 1 1
EOF
      fi


done

  return 0
}

# _update is called continuously, to collect the values
smartd_update() {
  # the first argument to this function is the microseconds since last update
  # pass this parameter to the BEGIN statement (see bellow).

  smartd_get || return 1

  # write the result of the work.
  for info  in $( cat /opt/netdata/share/smart_info )
  do
#echo "$DISK_TYPE,$SLOT_NUM,$DISK_DRIVE,$SN,$smart_health,$ATTR_NUM_5,$ATTR_NUM_187,$ATTR_NUM_197" 
    DISK_TYPE=$(echo $info| cut -d ',' -f 1)
    SLOT_NUM=$(echo $info| cut -d ',' -f 2)
    DISK=$(echo $info| cut -d ',' -f 3 | cut -d '/' -f 3)
    SN=$(echo $info| cut -d ',' -f 4)

    smartd_value1=$(echo $info| cut -d ',' -f 6 | awk -F: '{print $2}')
    smartd_value2=$(echo $info| cut -d ',' -f 7 | awk -F: '{print $2}')
    smartd_value3=$(echo $info| cut -d ',' -f 8 | awk -F: '{print $2}')
    smartd_value4=$(echo $info| cut -d ',' -f 9 | awk -F: '{print $2}')

    # echo  $DISK_TYPE $DISK $SLOT_NUM $DISK $SN $smartd_value1 $smartd_value2 $smartd_value3 $smartd_value4  
    if [ "$DISK_TYPE" == "sata" ];then


      cat << VALUESEOF
BEGIN smartd_${DISK}.status $1
SET Reallocated_Sectors_Count = $smartd_value1
SET Reported_Uncorrectable_Errors = $smartd_value2
SET Current_Pending_Sector = $smartd_value3
END
VALUESEOF
    elif [ "$DISK_TYPE" == "sas" ];then
      cat << VALUESEOF
BEGIN smartd_${DISK}.status $1
SET read_total_unc_errors = $smartd_value1
SET write_total_unc-errors = $smartd_value2
SET write_corr_algorithm_invocations = $smartd_value3
SET read_corr_algorithm_invocations = $smartd_value4
END
VALUESEOF

    elif [ "$DISK_TYPE" == "nvme" ];then
      cat << VALUESEOF
BEGIN smartd_${DISK}.status $1
SET media_and_data_integrity_errors = $smartd_value1
SET error_information_log_entries = $smartd_value2
END
VALUESEOF

    fi
  done

return 0
}