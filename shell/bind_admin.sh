#!/bin/bash
# bind_admin.sh -- add record for bind
# this script is used to manage dns record used for bind
# Author : sherwin
# Email: sherwinwangs@hotmail.com
# Create Date: 2016-03-02
# Modify Date: 2016-03-03

DOMAIN=$1
IPADDR=$2
DOMAIN_SUFFIX_BIT=$(echo $DOMAIN |sed 's/[^.]*\.\([^/]*\).*$/\1/')
DOMAIN_HOST_BIT=$(echo $DOMAIN |awk -F  '.' '{print $1}')
NAMED_ROOT="/var/named"

environment_check(){
	IP_RESULT=$(if [[ "$IPADDR" =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]];then echo "1";fi)
	DOMAIN_HOST_RESULT=$(if [[ "$DOMAIN_HOST_BIT" =~ ^[0-9a-zA-Z]+[0-9a-zA-Z\.-]* ]];then echo "1";fi)
	DOMAIN_SUFFIX_RESULT=$(cat /etc/named.rfc1912.zones |grep IN |awk -F "\"" '{print $2}'|tail -n +4|grep -w $DOMAIN_SUFFIX_BIT >/dev/null&& echo "1")
	DOMAIN_PTR_NAME=$(echo $IPADDR|awk 'BEGIN{OFS=FS="."}{print $3,$2,$1,"in-addr.arpa"}')
	DOMAIN_PTR_RESULT=$(cat /etc/named.rfc1912.zones |grep IN |awk -F "\"" '{print $2}'|tail -n +4|grep -w $DOMAIN_PTR_NAME >/dev/null&& echo "1")
	if [ "$IP_RESULT" == "1" ] && [ "$DOMAIN_HOST_RESULT" == "1" ] && [ "$DOMAIN_SUFFIX_RESULT" == "1" ] && [ "$DOMAIN_PTR_RESULT" == "1" ];then echo "1";else echo "0";fi
	echo -e "\n IP_ADDR:$IP_RESULT \n DOMAIN_HOST:$DOMAIN_HOST_RESULT \n DOMAIN_SUFFIX:$DOMAIN_SUFFIX_RESULT \n DOMAIN_PTR:$DOMAIN_PTR_RESULT"
}

add_record_a(){
	DOMAIN_ZONE_FILE=$NAMED_ROOT/${DOMAIN_SUFFIX_BIT}.zone
	CURRENT_SERIAL_NUM=$(cat $DOMAIN_ZONE_FILE|grep serial|head -n 1|awk '{print $1}')
	NEXT_SERIAL_NUM=$(expr $CURRENT_SERIAL_NUM + 1)
	sed -i "/serial$/s/$CURRENT_SERIAL_NUM/$NEXT_SERIAL_NUM/" $DOMAIN_ZONE_FILE 
	echo -e "$DOMAIN_HOST_BIT\t\t\tA\t$IPADDR" >>$DOMAIN_ZONE_FILE
	logger -t "bind_admin.sh" "change CURRENT_SERIAL_NUM:$CURRENT_SERIAL_NUM to NEXT_SERIAL_NUM:$NEXT_SERIAL_NUM for $DOMAIN_ZONE_FILE cause add $DOMAIN_HOST_BIT $IPADDR"
}

add_record_ptr(){
	NET_BROAD_BIT=$(echo $IPADDR |awk 'BEGIN{OFS=FS="."}{print $1,$2,$3}')
	HOST_IP_BIT=$(echo $IPADDR|awk -F "." '{print $NF}')
	DOMAIN_PTR_FILE=$(echo $NAMED_ROOT/${NET_BROAD_BIT}.rev)
	CURRENT_SERIAL_NUM=$(cat $DOMAIN_PTR_FILE|grep serial|head -n 1|awk '{print $1}')
	NEXT_SERIAL_NUM=$(expr $CURRENT_SERIAL_NUM + 1)
	sed -i "/serial$/s/$CURRENT_SERIAL_NUM/$NEXT_SERIAL_NUM/" $DOMAIN_PTR_FILE
	echo -e "$HOST_IP_BIT\t\t\tPTR\t${DOMAIN}." >>$DOMAIN_PTR_FILE
	logger -t "bind_admin.sh" "change CURRENT_SERIAL_NUM:$CURRENT_SERIAL_NUM to NEXT_SERIAL_NUM:$NEXT_SERIAL_NUM for $DOMAIN_PTR_FILE cause add $HOST_IP_BIT ${DOMAIN}."
}

restart_named(){
	/etc/init.d/named restart
}



env_check_ok=$(environment_check|head -n 1) 
if [ "$env_check_ok" == "1" ];then
	add_record_a $DOMAIN $IPADDR
	add_record_ptr $DOMAIN $IPADDR
	restart_named
else
	echo "environment check failed:"
	environment_check|tail -n -4 
fi
