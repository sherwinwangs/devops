#!/usr/bin/env bash
# cloud_replace_tpl.sh -- replace a vm template
# this script is used to replace a installed virtual machine template
# Author : sherwin
# Email: sherwinwangs@hotmail.com
# Create Date: 2015-06-02
# Modify Date: 2015-06-09


##Database Connection
HOSTNAME="127.0.0.1"
PORT="3306"
USERNAME="root"
PASSWORD=""
CLOUD_DB="cloud"

#VCenter Connection
VC_HOST="172.26.138.236"
VC_USER="administrator@vsphere.local"
VC_PASS="abCD12#$"
TPL_HOST="172.26.138.210"

#set -x
#Do not modify the content bellow
ova_file=$1
tpl_id=$2
vm_tpl_sql="SELECT vt.id,vt.unique_name,vt.name,vt.display_text,vt.size,vt.public,vt.hvm,tsr.install_path FROM vm_template vt JOIN template_store_ref tsr ON vt.id=tsr.template_id WHERE vt.removed IS NULL and vt.id='$tpl_id'"
tpl_spool_sql="SELECT tsr.template_id,sp.name,sp.uuid,sp.pool_type,tsr.install_path,tsr.last_updated FROM template_spool_ref tsr JOIN storage_pool sp ON tsr.pool_id=sp.id WHERE tsr.template_id='$tpl_id'"
if [ "$PASSWORD" == "" ];then
	tpl_array=($(mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} ${CLOUD_DB} -e "${vm_tpl_sql}" |sed -n '2,$p'))
	mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} ${CLOUD_DB} -e "${tpl_spool_sql}" |sed -n '2,$p'>/tmp/tpl_spool.txt
else
	tpl_array=($(mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} -p${PASSWORD} ${CLOUD_DB} -e "${vm_tpl_sql}" |sed -n '2,$p'))
	mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} -p${PASSWORD} ${CLOUD_DB} -e "${tpl_spool_sql}" |sed -n '2,$p'>/tmp/tpl_spool.txt
fi
decompress_dir=/tmp/${tpl_array[0]}
tpl_file=$(echo $ova_file|awk -F "/" '{print $NF}'|awk -F "." '{print $1}')
target_ova_file=$(echo ${tpl_array[7]}|awk -F "/" '{print $NF}')

environment_check(){
	if [ "$PASSWORD" == "" ];then
        	mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} ${CLOUD_DB} -e "show tables"  > /dev/null 2>&1
	else
        	mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} -p${PASSWORD} ${CLOUD_DB} -e "show tables" > /dev/null 2>&1
	fi
	if [ "$?" == "0" ];then
		echo "[1] Database Connection Check [Success]"
	else
		echo "[1] Database Connection Check [Failed]"
	fi

	OVFTOOL=$(which ovftool)
	if [ "$OVFTOOL" == "" ];then
		echo "[2] The tools must be installed Check [Failed]"
	else
		echo "[2] The tools must be installed Check [Success]"
	fi
#	echo "[3] VCenter Connection Check"
#	echo "[4] The Template ID to replace Check"
}

url_encode(){
    echo "$*" | awk 'BEGIN {
        split ("1 2 3 4 5 6 7 8 9 A B C D E F", hextab, " ")
        hextab [0] = 0
        for (i=1; i<=255; ++i) { 
            ord [ sprintf ("%c", i) "" ] = i + 0
        }
    }
    {
        encoded = ""
        for (i=1; i<=length($0); ++i) {
            c = substr ($0, i, 1)
            if ( c ~ /[a-zA-Z0-9.-]/ ) {
                encoded = encoded c             # safe character
            } else if ( c == " " ) {
                encoded = encoded "+"   # special handling
            } else {
                # unsafe character, encode it as a two-digit hex-number
                lo = ord [c] % 16
                hi = int (ord [c] / 16);
                encoded = encoded "%" hextab [hi] hextab [lo]
            }
        }
        print encoded
    }' 2>/dev/null
}



#decompress the ova file to tmp directory
decompress_ova() {
	if [ ! -d $decompress_dir ];then
  		mkdir -p $decompress_dir
 		if [ $? -gt 0 ];then
    			printf "Failed to create temp dir $decompress_dir\n" >&2
  		fi
	fi
	if [ ! -f $decompress_dir/${tpl_array[2]}.ovf ]
	then
		cp -f $ova_file $decompress_dir/$target_ova_file
		ovftool $decompress_dir/$target_ova_file  $decompress_dir/${tpl_array[2]}.ovf
	fi
}

#generate template.properties file
gen_properties(){
	date_now=$(date -u)
	target_dir=/tmp/$tpl_id
	vt_id=${tpl_array[0]}
	echo "#" > $target_dir/template.properties
	echo "#$date_now" >> $target_dir/template.properties
	echo "ova.virtualsize=${tpl_array[4]}" >>$target_dir/template.properties
	echo "filename=$target_ova_file" >>$target_dir/template.properties
	echo "ova.filename=$target_ova_file" >>$target_dir/template.properties
	echo "id=$tpl_id" >>$target_dir/template.properties
	if [ ${tpl_array[5]} == 1 ];then
		echo "public=true" >>$target_dir/template.properties
	else
		echo "public=false" >>$target_dir/template.properties
	fi
	echo "uniquename=${tpl_array[1]}" >>$target_dir/template.properties
	echo "virtualsize=$(ls -l $ova_file|awk -F ' ' '{print $5}')" >>$target_dir/template.properties
	echo "checksum=$(md5sum $ova_file |awk -F " " '{print $1}')" >>$target_dir/template.properties
	if [ ${tpl_array[6]} == 1 ];then
		echo "hvm=true" >>$target_dir/template.properties
	else
		echo "hvm=false" >>$target_dir/template.properties
	fi
	echo "ova=true" >>$target_dir/template.properties
	echo "description=${tpl_array[3]}" >>$target_dir/template.properties
	echo "ova.size=$(ls -l $ova_file|awk -F ' ' '{print $5}')" >>$target_dir/template.properties
	echo "size=$(ls -l $ova_file|awk -F ' ' '{print $5}')" >>$target_dir/template.properties
}

#generate and check SHA1 message digest
replace_tpl(){
	tpl_backup_dir="/root/kaopu/tplbak/"
	tpl_target_dir=$(find /export/secondaryLanYou/template/tmpl/ -name $tpl_id|awk -F "/" '{$NF="";print}'|tr " " "/")
	if [ ! -d $tpl_backup_dir ];then
  		mkdir -p $tpl_backup_dir
	fi
	if [ "$tpl_id" == "" ];then
		echo "the target template does not exist!"
	else
		if [ ! -d "$tpl_backup_dir/$tpl_id" ];then
			cp -rf $tpl_target_dir$tpl_id $tpl_backup_dir
		fi
		rm -f $tpl_target_dir$tpl_id/*
		cp -rf $target_dir $tpl_target_dir
		if [ "${tpl_array[0]}" == "" ];then
			echo "tpl id not exist"
		else
			date_update=$(date +%F\ %T|tr "-" "/")
			md5sum=$(md5sum $ova_file|awk -F " " '{print $1}')
			update_vt_sql="update vm_template set checksum='$md5sum',updated='$date_update' where id=${tpl_array[0]}"
			if [ "$PASSWORD" == "" ];then
				mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} ${CLOUD_DB} -e "${update_vt_sql}"
			else
				mysql -h${HOSTNAME} -P${PORT} -u${USERNAME} -p${PASSWORD} ${CLOUD_DB} -e "${update_vt_sql}"
			fi
		fi
	fi
}


#replace deployed template on storage
replace_deployed_tpl(){
	ENCODED_VC_USER=$(url_encode $VC_USER)
	ENCODED_VC_PASS=$(url_encode $VC_PASS)
	for sp_name in `cat /tmp/tpl_spool.txt|awk -F "\t" '{print $2}'`
		do
			STORAGE_NAME=$(cat /tmp/tpl_spool.txt |grep $sp_name|awk -F "\t" '{print $2}')	
			POOL_TYPE=$(cat /tmp/tpl_spool.txt|grep $sp_name|awk -F "\t" '{print $4}')
			if [ $POOL_TYPE == "VMFS" ];then
				VC_POOL_NAME=$(cat /tmp/tpl_spool.txt |grep $sp_name|awk -F "\t" '{print $2}')
			else
				VC_POOL_NAME=$(cat /tmp/tpl_spool.txt |grep $sp_name|awk -F "\t" '{print $3}'|tr -d "-")
			fi
			for installed_tpl in `cat /tmp/tpl_spool.txt|grep $sp_name|awk -F "\t" '{print $5}'`
				do
				ovftool --overwrite --network="VM Network" --name="$installed_tpl" --datastore="$VC_POOL_NAME" $decompress_dir/$target_ova_file vi://$ENCODED_VC_USER:$ENCODED_VC_PASS@$VC_HOST/?ip=$TPL_HOST
				done
		done	
}

cleanup_tmp_file(){
	rm -rf $decompress_dir 
	rm -f /tmp/tpl_spool.txt
}

usage() {
  printf "Usage: %s [ovf_file] [target_template_id] {install|check|[urlencode] url_str }\n" $(basename $0) >&2
}

case "$3" in
  install)
	decompress_ova
	echo "[1] decompress ova success!"
	gen_properties
	echo "[2] generate template.properties success!"
	replace_tpl
	echo "[3] replace template success!"
	replace_deployed_tpl
	echo "[4] replace deployed template success!"
	cleanup_tmp_file
	echo "[5] success cleanup tmp files!"
        ;;
  check)
	environment_check
        ;;
  urlencode)
	url_encode $4
	;;
  *)
        usage
        RETVAL=2
esac

exit $RETVAL
