#!/usr/bin/env python
# encoding: utf-8
import os
import sys
import re
import json
import types
import shutil
import time
from subprocess import Popen, PIPE


def sys_invoke(cmd, wait=True, option=0):
    stdout = ''
    status = 0
    stderr = ''
    process = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
    if wait:
        process.wait()

    status = process.returncode
    (stdout, stderr) = process.communicate()
    if option in [0, False]:
        return (status, stdout.strip(), stderr.strip())
    if option in [1, True]:
        return status
    if option in (2, ):
        return stdout.strip()
    if option in (3, ):
        return stderr.strip()
    return (status, stdout.strip(), stderr.strip())


def get_teminal_input(tips='Pls input', options=['y', 'n', 'yes', 'no']):
    data = ''
    while True:
        data = raw_input(tips)
        if data in options:
            break
            continue
    return data


class Color:
    BLACK = 0
    RED = 1
    GREEN = 2
    YELLOW = 3
    BLUE = 4


def log(str=''):
    print '\x1b[0;3%dm%s\x1b[0m' % (Color.GREEN, str)


def error(str=''):
    print '\x1b[0;3%dm%s\x1b[0m' % (Color.RED, str)


def warning(str=''):
    print '\x1b[0;3%dm%s\x1b[0m' % (Color.YELLOW, str)


def quit(code=0, msg=''):
    if msg:
        print msg

    sys.exit(code)


def usage():
    print 'Usge : $0 doamin'
    print 'e.g : $0 www.888msc.com'
    quit(1, 'exit 1')


def prepare():
    sta = sys_invoke('rpm -q expect', True, 1)
    if sta != 0:
        sta = sys_invoke('yum install expect -y', True, 1)

    sta = sys_invoke('rpm -q openssl', True, 1)
    if sta != 0:
        sta = sys_invoke('yum -y install openssl openssl-devel', True, 1)

    if not os.path.isfile('/etc/pki/CA/index.txt'):
        os.mknod('/etc/pki/CA/index.txt')

    if not os.path.isfile('/etc/pki/CA/serial'):
        f = open('/etc/pki/CA/serial', 'w')
        f.write('00')
        f.close()

    if not os.path.isfile('/etc/pki/CA/crlnumber'):
        f = open('/etc/pki/CA/crlnumber', 'w')
        f.write('01')
        f.close()

    return True


def passwd_key(op):
    string = ''
    if op == 'ca':
        string = 'it is important !'
    else:
        string = 'it is not important'
    password = ''
    while True:
        password = raw_input(
            'Please input a NEW PASSWORD of ' + op + '.key(' + string + '): ')
        if len(password) < 4:
            print 'You must type in 4 to 8191 characters '
            continue
        break
    print 'password = ' + password
    return password


def create_key(op1, op2, op3):
    li = 'expect -c "spawn openssl genrsa -aes256 -out ' + op3 + '/' + op2 + '.key 1024\n expect {\n \\"Enter pass phrase\\" { send \\"' + op1 + '\n\\";exp_continue;}\n\\"Verifying\\" { send \\"$1\n\\";}\n}\n expect eof\n"'
    (sta, out, err) = sys_invoke(li)
    print out
    return sta


def create_ca():
    print '######################### start to create ca file ########################'
    password = passwd_key('ca')
    li = 'expect -c "spawn openssl req -days 3650 -new -x509 -keyout ca.key -out ca.crt\n expect {\n \\"phrase\\" { send \\"' + password + '\n\\";exp_continue;}\n \\"Verifying\\" {send \\"' + password + '\n\\";exp_continue;}\n \\"Country Name\\" {send \\"PH\n\\";exp_continue;}\n\\"Province Name\\" { send \\"Ph\n\\";exp_continue;}\n\\"Locality Name\\" { send \\"KaKa\n\\";exp_continue;}\n\\"Organization Name\\" { send \\"Sun\n\\";exp_continue;}\n\\"Organizational Unit Name\\" { send \\"SunBet\n\\";exp_continue;}\n\\"Common Name\\" { send \\"$1\n\\";exp_continue;}\n\\"Email Address\\" { send \\"sunbet16889@126.com\n\\";}\n}\n expect eof\n"'
    (sta, out, err) = sys_invoke(li)
    print out
    return sta


def create_csr(op1, op2, op3, op4):
    li = 'expect -c "spawn openssl req -days 3650 -new -key ' + op3 + '/' + op2 + '.key -out ' + op3 + '/' + op2 + '.csr\n expect {\n \\"Enter pass phrase\\" { send \\"' + op4 + '\n\\";exp_continue;}\n\\"Country Name\\" { send \\"PH\n\\";exp_continue;}\n\\"Province Name\\" { send \\"Ph\n\\";exp_continue;}\n\\"Locality Name\\" { send \\"KaKa\n\\";exp_continue;}\n\\"Organization Name\\" { send \\"Sun\n\\";exp_continue;}\n\\"Organizational Unit Name\\" { send \\"SunBet\n\\";exp_continue;}\n\\"Common Name\\" { send \\"' + op1 + '\n\\";exp_continue;}\n\\"Email Address\\" { send \\"sunbet16889@126.com\n\\";exp_continue;}\n\\"challenge password\\" { send \\"' + op4 + '\n\\";exp_continue;}\n\\"company name\\" { send \\"Sun\n\\";}\n}\n expect eof\n"'
    (sta, out, err) = sys_invoke(li)
    print out
    return sta


def create_crt(op1, op2, op3):
    li = 'expect -c "spawn openssl ca -in ' + op3 + '/' + op2 + '.csr -out ' + op3 + '/' + op2 + '.crt -cert ca.crt -keyfile ca.key\n expect {\n \\"phrase for ca.key\\" { send \\"' + op1 + '\n\\";exp_continue;}\n\\"y/n\\" { send \\"y\n\\";exp_continue;}\n\\"y/n\\" { send \\"y\n\\";}\n}\n expect eof\n"'
    (sta, out, err) = sys_invoke(li)
    print out
    return sta


def create_p12(op1, op2, op3, op4):
    li = 'expect -c "spawn openssl pkcs12 -export -inkey ' + op3 + '/' + op2 + '.key -in ' + op3 + '/' + op2 + '.crt -out ' + op3 + '/' + op2 + '.p12\n expect {\n \\"Enter pass phrase\\" { send \\"' + op4 + '\n\\";exp_continue;}\n\\"Password\\" { send \\"' + op1 + '\n\\";exp_continue;}\n\\"Verifying\\" { send \\"' + op1 + '\n\\";}\n}\n expect eof\n"'
    (sta, out, err) = sys_invoke(li)
    print out
    return sta


def create_server():
    ca_passwd = raw_input('Please input the password of ca.key: ')
    password = passwd_key('server')
    print '######################### start to create key file #######################'
    create_key(password, 'server', '.')
    print '######################### start to create csr file #######################'
    create_csr(g_domain, 'server', '.', password)
    print '######################### start to create crt file #######################'
    create_crt(ca_passwd, 'server', '.')
    return True


def create_client():
    ca_passwd = raw_input('Please input the password of ca.key: ')
    name = raw_input('Please input the name of key: ')
    cli_passwd = passwd_key('client')
    if not os.path.isdir(name):
        os.mkdir(name)

    print '######################### start to create key file #######################'
    create_key(cli_passwd, name, name)
    print '######################### start to create csr file #######################'
    create_csr(name, name, name, cli_passwd)
    print '######################### start to create crt file #######################'
    create_crt(ca_passwd, name, name)
    print '######################### start to create p12 file #######################'
    rand_pass = sys_invoke('openssl rand -base64 9', True, 2)
    print 'random password :' + rand_pass
    passwd = rand_pass
    p12_passwd = passwd_key('client.p12')
    print 'p12_passwd is : ' + p12_passwd
    f = open(name + '/' + passwd, 'w')
    f.write(p12_passwd + '\n')
    print 'Your password ' + p12_passwd + ' have save in file ' + name + '/' + passwd + ' ,please check'
    create_p12(p12_passwd, name, name, cli_passwd)
    return True


def revoke_crt():
    ca_passwd = raw_input('Please input the password of ca.key: ')
    name = raw_input(
        'Please input a crt file name you want to revoke(example: client): ')
    if not os.path.isfile(name + '/' + name + '.crt'):
        print 'The ' + name + '/' + name + '.crt' + ' does not exist. Please check out!!!!'
        quit(1, 'quit')

    li = 'expect -c "spawn openssl ca -revoke ' + name + '/' + name + '.crt -keyfile ca.key -cert ca.crt\n expect {\n \\"Enter pass phrase\\" { send \\"' + ca_passwd + '\n\\";exp_continue;}\n}\n expect eof\n"'
    (sta, out, err) = sys_invoke(li)
    print out
    li = 'expect -c "spawn openssl ca -gencrl -out ca.crl -keyfile ca.key -cert ca.crt\n expect {\n \\"Enter pass phrase\\" { send \\"' + ca_passwd + '\n\\";exp_continue;}\n}\n expect eof\n"'
    (sta, out, err) = sys_invoke(li)
    print out
    return sta


def num_input():
    tips = 'Please input a number\n 1: Create a root certificate\n 2: Create a server certificate\n 3: Create a client certificate\n 4: Revoke the crt file\n Number = '
    num = get_teminal_input(tips, ['1', '2', '3', '4'])
    if num == '1':
        prepare()
        create_ca()
    elif num == '2':
        prepare()
        create_server()
    elif num == '3':
        prepare()
        create_client()
    elif num == '4':
        revoke_crt()
    else:
        num_input()
    return True


g_domain = ''
if len(sys.argv) != 2:
    usage()
else:
    g_domain = sys.argv[1]
    num_input()