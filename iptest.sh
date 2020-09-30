#!/bin/bash 
args_temp=$(getopt -o i:m:d: -- "$@")
test_cmd_fail_exit="Use $0 [-c|-o var]"
eval set -- "$args_temp"
while true; do
    case $1 in
    -i) 
        ip=$2
        shift
        ;;
    -m) 
        mask=$2
        shift
        ;;
    -d) 
        ifname=$2
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

#分段轉變量
IFS=. read -r i1 i2 i3 i4 <<< "$ip"
IFS=. read -r m1 m2 m3 m4 <<< "$mask"

mask2cdr ()
{
   # Assumes there's no "255." after a non-255 byte in the mask
   local x=${1##*255.}
   set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
   x=${1%%$3*}
   echo $(( $2 + (${#x}/4) ))
}

cdr2mask ()
{
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}

echo "network:   $((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$((i4 & m4))"
echo "broadcast: $((i1 & m1 | 255-m1)).$((i2 & m2 | 255-m2)).$((i3 & m3 | 255-m3)).$((i4 & m4 | 255-m4))"
echo "first IP:  $((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$(((i4 & m4)+1))"
echo "last IP:   $((i1 & m1 | 255-m1)).$((i2 & m2 | 255-m2)).$((i3 & m3 | 255-m3)).$(((i4 & m4 | 255-m4)-1))"

#排除前兩個ip (交換機和管理機本身的ip)
fIP=$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$(((i4 & m4)+3))
lIP=$((i1 & m1 | 255-m1)).$((i2 & m2 | 255-m2)).$((i3 & m3 | 255-m3)).$(((i4 & m4 | 255-m4)-1))

subnet=$(echo $fIP | cut -d '.' -f 1-3)
startnum=$(echo $fIP | cut -d '.' -f 4)
endnum=$(echo $lIP | cut -d '.' -f 4)
#增加浮動ip
i=0
echo "#!/bin/bash" >  /tmp/deleteip.sh
prefix=$(mask2cdr $mask)
for j in $(seq $startnum  $endnum)
do

ip addr add $subnet.$j/$prefix  dev $ifname label $ifname:$i

let "i=i+1"
#/tmp/deleteip.sh 用來手動刪ip
echo "ip addr delete $subnet.$j/$prefix dev $ifname " >> /tmp/deleteip.sh
done
