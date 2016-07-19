#!/bin/bash
# create_ssl.sh -- create and sign ssl certfication
# this script is used to create and sign ssl certfication
# Author : sherwin
# Email: sherwinwangs@hotmail.com
# Create Date: 2016-01-02
# Modify Date: 2016-01-09

# requirement:
# yum install expect
# touch /etc/pki/CA/index.txt
# echo "00" >> /etc/pki/CA/serial
# echo "01" >/etc/pki/CA/crlnumber
# if you got error message "failed to update database TXT_DB error number 2" when you want to create file crt
# you can change "unique_subject = no" in "/etc/pki.CA/index.txt.attr " file


passwd_key(){
	if [ $1 == "ca" ] ;then
		string="it is important !"
	else
		string="it is not important"
	fi
	while true
	do
		read -p "Please input a NEW PASSWORD of $1.key($string): " password
		num=`expr length $password`
		if [ ${num} -lt 4 ] ;then
			echo "You must type in 4 to 8191 characters "
		else
			break
		fi
	done
	echo "$password"
}

prepare(){
	rpm -q expect >/dev/null
	if [ $? -ne 0 ] ;then
		yum install expect
	fi

	if [ ! -f /etc/pki/CA/index.txt ] ;then
		touch /etc/pki/CA/index.txt
	fi

	if [ ! -f /etc/pki/CA/serial ] ;then
		echo "00" > /etc/pki/CA/serial
	fi

	if [ ! -f /etc/pki/CA/crlnumber ] ;then
		echo "01" > /etc/pki/CA/crlnumber
	fi
}		
create_key(){
	cmd="openssl genrsa -aes256 -out $3/$2.key 1024"
	expect -c "
		spawn $cmd
	expect {
		\"Enter pass phrase\" { send \"$1\n\";exp_continue;}
		\"Verifying\" { send \"$1\n\";}
	}
	expect eof
	"
}
create_csr(){
	cmd="openssl req -days 3650 -new -key $3/$2.key -out $3/$2.csr"
	expect -c "
		spawn $cmd
	expect {
		\"Enter pass phrase\" { send \"$4\n\";exp_continue;}
		\"Country Name\" { send \"PH\n\";exp_continue;}
		\"Province Name\" { send \"Ph\n\";exp_continue;}
		\"Locality Name\" { send \"KaKa\n\";exp_continue;}
		\"Organization Name\" { send \"Sun\n\";exp_continue;}
		\"Organizational Unit Name\" { send \"SunBet\n\";exp_continue;}
		\"Common Name\" { send \"$1\n\";exp_continue;}
		\"Email Address\" { send \"sunbet16889@126.com\n\";exp_continue;}
		\"challenge password\" { send \"$4\n\";exp_continue;}
		\"company name\" { send \"Sun\n\";}
	}
	expect eof	
	"	
}
create_crt(){
	cmd="openssl ca -in $3/$2.csr -out $3/$2.crt -cert ca.crt -keyfile ca.key"
	expect -c "
		spawn $cmd
	expect {
		\"phrase for ca.key\" { send \"$1\n\";exp_continue;}
		\"y/n\" { send \"y\n\";exp_continue;}
		\"y/n\" { send \"y\n\";}
	}
	expect eof
	"
}
create_p12(){
	cmd="openssl pkcs12 -export -inkey $3/$2.key -in $3/$2.crt -out $3/$2.p12"
	expect -c "
		spawn $cmd
	expect {
		\"Enter pass phrase\" { send \"$4\n\";exp_continue;}
		\"Password\" { send \"$1\n\";exp_continue;}
		\"Verifying\" { send \"$1\n\";}
	}
	expect eof
	"
}
create_ca(){
	echo "######################### start to create ca file ########################"
	password=`passwd_key ca`
	cmd="openssl req -days 3650 -new -x509 -keyout ca.key -out ca.crt"
	expect -c "
		spawn $cmd 
	expect {
		\"phrase\" { send \"$password\n\";exp_continue;}
		\"Verifying\" {send \"$password\n\";exp_continue;}
		\"Country Name\" {send \"PH\n\";exp_continue;}
		\"Province Name\" { send \"Ph\n\";exp_continue;}
		\"Locality Name\" { send \"KaKa\n\";exp_continue;}
		\"Organization Name\" { send \"Sun\n\";exp_continue;}
		\"Organizational Unit Name\" { send \"SunBet\n\";exp_continue;}
		\"Common Name\" { send \"$1\n\";exp_continue;}
              	\"Email Address\" { send \"sunbet16889@126.com\n\";}
	}
	expect eof
	"	
}
create_server(){
	read -p "Please input the password of ca.key: " ca_passwd
	password=`passwd_key server`
	echo "######################### start to create key file #######################"
	create_key $password 'server' '.'
	echo "######################### start to create csr file #######################"
	create_csr $domain 'server' '.' $password
	echo "######################### start to create crt file #######################"
	create_crt $ca_passwd 'server' '.'
}
create_client(){
	read -p "Please input the password of ca.key: " ca_passwd
	read -p "Please input the name of key: " name
	cli_passwd=`passwd_key client`
	mkdir $name
	echo "######################### start to create key file #######################"
	create_key $cli_passwd $name $name
	echo "######################### start to create csr file #######################"
	create_csr $name $name $name $cli_passwd
	echo "######################### start to create crt file #######################"
	create_crt $ca_passwd $name $name $cli_passwd
	echo "######################### start to create p12 file #######################"
	echo "random password :$(openssl rand -base64 9)"
	p12_passwd=`passwd_key client.p12`
	#read -p "Please input a passwd to export/import $name/$name.p12:(it is important) " p12_passwd
	echo "$p12_passwd" >$name/passwd
	echo "Your password $p12_passwd have save in file $name/passwd ,please check"
	create_p12 $p12_passwd $name $name $cli_passwd
}
revoke_crt(){
	read -p "Please input the password of ca.key: " ca_passwd
	read -p "Please input a crt file name you want to revoke(example: client): " name
	if [ ! -f $name/$name.crt ] ;then
		echo "The $name/$name.crt does not exist. Please check out!!!!"
		exit 1
	else
		cmd="openssl ca -revoke $name/$name.crt -keyfile ca.key -cert ca.crt"
		expect -c "
			spawn $cmd
		expect {
			\"Enter pass phrase\" { send \"$ca_passwd\n\";exp_continue;}
		}
		expect eof
		"
		cmd="openssl ca -gencrl -out ca.crl -keyfile ca.key -cert ca.crt"
		expect -c "
		expect {	
			\"Enter pass phrase\" { send \"$ca_passwd\n\";exp_continue;}
		}
		expect eof
		"
	fi
}	
num_input(){
	read -p "Please input a number 
1: Create a root certificate 
2: Create a server certificate 
3: Create a client certificate 
4: Revoke the crt file
Number = " num
case $num in 1)
	prepare
	create_ca ;;
	2)
	prepare
	create_server ;;
	3)
	prepare
	create_client ;;
	4)
	revoke_crt ;;
	*)
	num_input;;
	esac
}

if [ $# -ne 1 ] ;then
	echo "Usge : $0 doamin "
	echo "e.g : $0 www.aaa.com "
	echo "exit 1"
	exit 1
fi

export domain=$1
num_input
