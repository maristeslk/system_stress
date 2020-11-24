# shellcheck shell=bash
# no need for shebang - this file is loaded from charts.d.plugin
# SPDX-License-Identifier: GPL-3.0-or-later

# netdata
# real-time performance and health monitoring, done right!
# (C) 2016 Costa Tsaousis <costa@tsaousis.gr>
#

# if this chart is called X.chart.sh, then all functions and global variables
# must start with X_
# _update_every is a special variable - it holds the number of seconds
# between the calls of the _update() function
smartd_update_every=60

# the priority is used to sort the charts on the dashboard
# 1 = the first chart
smartd_priority=130000

# to enable this chart, you have to set this to 12345
# (just a demonstration for something that needs to be checked)
smartd_magic_number=4869

# global variables to store our collected data
# remember: they need to start with the module name smartd_
# DISKSN_PATH='/tmp/disk_sn.txt'
# SMARTINFO_PATH='/tmp/smart_info.txt'
CONTROLL_TYPE='direct'
vendor=$(dmidecode -s system-manufacturer | tail -n 1)
system_version=$(cat /etc/lsb-release  | grep DISTRIB_RELEASE | cut -d '=' -f 2)
case $vendor in
 *Powerleader*)
        vendor="powerleader"
        ;;
 *H3C*)
        vendor="h3c"
        ;;
 *Lenovo*)
        vendor="lenovo"
        raid_tool='sudo storcli64'
        ;;
 *Huawei*)
        vendor="huawei"
        raid_tool='sudo storcli64'
        ;;
 *Dell*)
        vendor="dell"
        raid_tool='sudo perccli64'
        ;;
 *HP*)
        vendor="hp"
        ;;
 *Inspur*)
        vendor="inspur"
        ;;
 *Supermicro*)
        vendor="supermicro"
        ;;
 *Cisco*)
        vendor="cicso"
        ;;
 *)
        echo "not match machine vendor"
        exit 1
        ;;
esac

IF_MEGA=$(smartctl --scan | grep "megaraid")
if [ -n "$IF_MEGA" ];then
    CONTROLL_TYPE="megaraid"
fi

IF_CCISS=$(smartctl --scan | grep "cciss")
if [ -n "$IF_CCISS" ];then
    CONTROLL_TYPE="cciss"
fi
#判读机器有没有nvme
IFNVME='0'
IF_NVME=$(lspci |  grep -i 'nvme')
if [ -n "$IF_NVME" ];then
  IFNVME='1'
fi

smartd_create() {



  if [ "$CONTROLL_TYPE" == "megaraid" ];then
      for DISK_DRIVE in $(${raid_tool} /c0/eALL/sALL show all | egrep 'Device attributes' | awk '{print $2}' )
        do
          SLOT_NUM=$(echo ${DISK_DRIVE} | cut -d '/' -f 4 | awk -v FS='s' '{print $2}')
          ENS_NUM=$(echo ${DISK_DRIVE} | cut -d '/' -f 3 | awk -v FS='e' '{print $2}')
          ens_slot="${ENS_NUM}:${SLOT_NUM}"

          
          DISK=$(sudo megaclisas-status  | awk -v FS='|' '{print $8 $10}'  |grep -w "${ens_slot}" | awk -v FS='/' '{print $3}' )
          if [  ! -n "$DISK"  ];then
          #保留原始的/c0/e11/s1格式 后续会被处理 
            DISK=$(echo ${DISK_DRIVE} | sed "s:\/dev\/::" | sed "s:\/::g")
          fi
          #用lsiID 才能用smart取到sn
          LSI_ID=$(sudo megaclisas-status  | awk -v FS='|' '{print $8 $9}'  |grep -w "${ens_slot}" | awk '{print $2}' )
          SN=$(smartctl -d megaraid,${LSI_ID}  -a /dev/sda | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')

          IF_DISK_TYPE=$(smartctl -d megaraid,${LSI_ID}  -a /dev/sda | grep -i 'SATA')
          if [ "$IF_DISK_TYPE" == "" ];then
            DISK_TYPE='sas'
          else
            DISK_TYPE='sata'
          fi
          tmpinfo="$DISK_TYPE;$SLOT_NUM;$DISK;$SN;$LSI_ID"
          SMART_INFO+=" ${tmpinfo}"

          if [ "$DISK_TYPE" == "sata" ];then
  #CHART type.id         name    title                   units [family  [context [charttype [priority [update_every [options [plugin [module]]]]]]]]
            cat  << EOF
CHART  smartd_status.${DISK} '' "smart_info on ${DISK}" "S.M.A.R.T value" "${DISK}" "smartd_status" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION Reallocated_Sectors_Count 'Reallocated_Sectors_Count'  absolute 1 1
DIMENSION Reported_Uncorrectable_Errors 'Reported_Uncorrectable_Errors' absolute 1 1
DIMENSION Current_Pending_Sector 'Current_Pending_Sector' absolute 1 1
EOF
          elif [ "$DISK_TYPE" == "sas" ];then
            cat  << EOF
CHART  smartd_status.${DISK} '' "smart_info on ${DISK}" "S.M.A.R.T value" "${DISK}" "smartd_status" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION read_total_unc_errors 'read_total_unc_errors' absolute 1 1
DIMENSION write_total_unc-errors 'write_total_unc-errors' absolute 1 1
DIMENSION write_corr_algorithm_invocations 'write_corr_algorithm_invocations' absolute 1 1
DIMENSION read_corr_algorithm_invocations 'read_corr_algorithm_invocations' absolute 1 1
EOF
          fi
        done



    elif [ "$CONTROLL_TYPE" == "direct" ];then
      #初版只满足直通的服务器

      for DISK_DRIVE in $( ls /dev/sd* | grep -E "/dev/sd[a-z]$")
        do
              SN=$(smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
              DISK=$(echo ${DISK_DRIVE} | sed "s:\/dev\/::" | sed "s:\/::g")
              SLOT_NUM=$( lsscsi | grep $DISK_DRIVE | awk '{print $1}')
              SLOT_NUM=${SLOT_NUM#"["}
              SLOT_NUM=${SLOT_NUM%"]"}
              IF_DISK_TYPE=$(smartctl  -a $DISK_DRIVE | grep -i 'SATA')
              if [ "$IF_DISK_TYPE" == "" ];then
                DISK_TYPE='sas'
              else
                DISK_TYPE='sata'
              fi
                tmpinfo="$DISK_TYPE;$SLOT_NUM;$DISK_DRIVE;$SN"
                SMART_INFO+=" ${tmpinfo}"
            # echo "$DISK_TYPE;$SLOT_NUM;$DISK_DRIVE;$SN" | tee  $DISKSN_PATH
          if [ "$DISK_TYPE" == "sata" ];then
  #CHART type.id         name    title                                    units [family [context [charttype [priority [update_every [options [plugin [module]]]]]]]]
        cat  << EOF
CHART  smartd_status.${DISK} '' "smart_info on ${DISK}" "S.M.A.R.T value" "${DISK}" "smartd_status" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION Reallocated_Sectors_Count 'Reallocated_Sectors_Count'  absolute 1 1
DIMENSION Reported_Uncorrectable_Errors 'Reported_Uncorrectable_Errors' absolute 1 1
DIMENSION Current_Pending_Sector 'Current_Pending_Sector' absolute 1 1
EOF
        elif [ "$DISK_TYPE" == "sas" ];then
        cat  << EOF
CHART  smartd_status.${DISK} '' "smart_info on ${DISK}" "S.M.A.R.T value" "${DISK}" "smartd_status" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION read_total_unc_errors 'read_total_unc_errors' absolute 1 1
DIMENSION write_total_unc-errors 'write_total_unc-errors' absolute 1 1
DIMENSION write_corr_algorithm_invocations 'write_corr_algorithm_invocations' absolute 1 1
DIMENSION read_corr_algorithm_invocations 'read_corr_algorithm_invocations' absolute 1 1
EOF
          fi
    done


  fi

    #判断是否有nvme盘
  if [ "$IFNVME" == "1" ];then
      for DISK_DRIVE in $( ls /dev/nvme* | grep -E "/dev/nvme[0-9]$")
        do
                SN=$(smartctl  -a $DISK_DRIVE | grep  -E "[S|s]erial [N|n]umber:"  | awk '{print $3}')
                SLOT_NUM=$( lspci |  grep -i 'nvme' | awk '{print $1}')
                DISK_TYPE='nvme'
                DISK=$(echo ${DISK_DRIVE} | sed "s:\/dev\/::" | sed "s:\/::g")

                tmpinfo="$DISK_TYPE;$SLOT_NUM;$DISK_DRIVE;$SN"
                SMART_INFO+=" ${tmpinfo}"
        cat  << EOF
CHART  smartd_status.${DISK} '' "smart_info on ${DISK}" "S.M.A.R.T value" "${DISK}" "smartd_status" smart_value smart_info_${DISK} line $((smartd_priority + 1)) $smartd_update_every
DIMENSION media_and_data_integrity_errors 'media_and_data_integrity_errors' absolute 1 1
DIMENSION error_information_log_entries 'error_information_log_entries' absolute 1 1
EOF
        done
    fi

  return 0
}
smartd_get() {
    
    for info  in $SMART_INFO
        do
                #获取磁盘 sn 
                DISK_TYPE=$(echo $info| cut -d ';' -f 1)
                SLOT_NUM=$(echo $info| cut -d ';' -f 2)
                SN=$(echo $info| cut -d ';' -f 4)
                #DISK_DRIVE用来给smartctl扫描用
                DISK_DRIVE=$(echo $info| cut -d ';' -f 3)
                #DISK是用来简化 统一指标名称 sda nvme0
                DISK=$(echo ${DISK_DRIVE} | sed "s:\/dev\/::" | sed "s:\/::g")
                #DISK=${DISK_DRIVE}
                #根据raid类型获取健康状态
                if [ "$CONTROLL_TYPE" == "megaraid" ];then
                    LSI_ID=$(echo $info| cut -d ';' -f 5)
                    smart_health=$(smartctl -d megaraid,$LSI_ID  -H  "${DISK_DRIVE}" | grep -E "^SMART*"  | cut -d ':' -f 2 | cut -d "[" -f 1 |tr ' ' '_')
                elif  [ "$CONTROLL_TYPE" == "direct" ];then
                    smart_health=$(smartctl -H  "${DISK_DRIVE}" | grep -E "^SMART*" | cut -d ':' -f 2 | cut -d "[" -f 1 |tr ' ' '_')
                fi

                OLD_IFS=$IFS;
                smart_health=${smart_health#"_"}
                smart_health=${smart_health%"_"}

                if [ "$smart_health" = "OK" ] ||  [ "$smart_health" = "PASSED" ];then
                    :
                else
                    smart_health=$(smartctl  -H  "${DISK_DRIVE}" | grep -E "^SMART*"  | cut -d ':' -f 2  |  tr " " "_" | cut -d '[' -f 1 )
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
                                          ATTR_NUM_5="${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "187" ];then
                                          ATTR_NUM_187="${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "197" ];then
                                          ATTR_NUM_197="${ATTR_VALUE}"
                                  fi
    
                              elif  [ "$attr_key" == 'string' ] && [ "$DISK_TYPE" == "sas" ];then

                                  ATTR_VALUE=$(echo $ATTR| cut -d ';' -f 2)

                                  if [ "$ATTR_NAME" == "read-total-unc-errors" ];then
                                          RTUE="${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "write-total-unc-errors" ];then
                                          WTUE="${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "write-corr-algorithm-invocations" ];then
                                          WCAI="${ATTR_VALUE}"
                                  elif [ "$ATTR_NAME" == "read-corr-algorithm-invocations" ];then
                                          RCAI="${ATTR_VALUE}"
                                  fi
                              elif  [ "$attr_key" == "string" ] && [ "$DISK_TYPE" == "sata" ];then
                                  :
                              elif  [ "$attr_key" == "int" ] && [ "$DISK_TYPE" == "sas" ];then
                                  :
                              fi
                      done
                      if [ "$attr_key" == 'int' ] && [ "$DISK_TYPE" == "sata" ];then
                        # echo "$DISK_TYPE,$SLOT_NUM,$DISK_DRIVE,$SN,$smart_health,$ATTR_NUM_5,$ATTR_NUM_187,$ATTR_NUM_197" >> $SMARTINFO_PATH
                          cat  << VALUESEOF
BEGIN smartd_status.${DISK} $1
SET Reallocated_Sectors_Count = $ATTR_NUM_5
SET Reported_Uncorrectable_Errors = $ATTR_NUM_187
SET Current_Pending_Sector = $ATTR_NUM_197
END
VALUESEOF
                        elif  [ "$attr_key" == "string" ] && [ "$DISK_TYPE" == "sas" ];then
                        # echo "$DISK_TYPE,$SLOT_NUM,$DISK_DRIVE,$SN,$smart_health,$RTUE,$WTUE,$WCAI,$RCAI" >> $SMARTINFO_PATH
                          cat  << VALUESEOF
BEGIN smartd_status.${DISK} $1
SET read_total_unc_errors = $RTUE
SET write_total_unc-errors = $WTUE
SET write_corr_algorithm_invocations = $WCAI
SET read_corr_algorithm_invocations = $RCAI
END
VALUESEOF
                        elif  [ "$attr_key" == "string" ] && [ "$DISK_TYPE" == "sata" ];then
                                :
                        elif  [ "$attr_key" == "int" ] && [ "$DISK_TYPE" == "sas" ];then
                                :
                      fi
                  else
                    MDIE=$(smartctl -x  ${DISK_DRIVE}  | grep -i 'Media and Data Integrity Errors' | awk -F: '{print $2}' |sed s/[[:space:]]//g)
                    # data_integ_errors="media_and_data_integrity_errors:${media_and_data_integrity_errors}"
                    EILE=$(smartctl -x  ${DISK_DRIVE}  | grep -i 'Error Information Log Entries' | awk -F: '{print $2}'|sed s/[[:space:]]//g)
                    # error_infor_log_entries="error_information_log_entries:${error_information_log_entries}"
                    # echo "$DISK_TYPE,$SLOT_NUM,$DISK_DRIVE,$SN,$smart_health,$data_integ_errors,$error_infor_log_entries" >> $SMARTINFO_PATH
                    cat  << VALUESEOF
BEGIN smartd_status.${DISK} $1
SET media_and_data_integrity_errors = $MDIE
SET error_information_log_entries = $EILE
END
VALUESEOF
                    fi
        done

  return 0
}

# _check is called once, to find out if this chart should be enabled or not
smartd_check() {
  # this should return:
  #  - 0 to enable the chart
  #  - 1 to disable the chart

  # require_cmd smartctl && [ ! -d "$DISKSN_PATH" ] && return 0
  require_cmd smartctl && require_cmd lsscsi  && return 0
  #   # check that we can collect data
  #   smartd_get || return 1
    return 0
}

# _create is called once, to create the charts


# _update is called continuously, to collect the values
smartd_update() {
  # the first argument to this function is the microseconds since last update
  # pass this parameter to the BEGIN statement (see bellow).

  smartd_get || return 1



return 0
}