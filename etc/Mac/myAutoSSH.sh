#!/bin/bash

#KEYFILE="$HOME/Dropbox/Galaxy/dotfiles/ssh/GalaxyMini"
#KEYFILE='-i /Users/Galaxy/Dropbox/Galaxy/dotfiles/ssh/GalaxyMini'
COMMONARG='-o ServerAliveInterval=59 -N -f'
NoHostKeyCheck='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
RandomPort='RANDOM % 64000 + 1024'

#/usr/local/bin/autossh -M $(($RANDOM%64000 + 1024)) -f galaxy@svps.pinkplus.org -6 -p 26386 -C -D 7575 $COMMONARG $KEYFILE
#/usr/local/bin/autossh -M $(($RandomPort)) -f galaxy@svps.pinkplus.org -p 22 -C -D 7575 $COMMONARG $KEYFILE
/usr/local/bin/autossh -M $(($RandomPort)) -f galaxy@2403:3a00:202:1129:49:212:210:128 -p 26386 -C -D7575 $COMMONARG $KEYFILE

/usr/local/bin/autossh -M $(($RandomPort)) -f luolab@eeb-zhanglab.eeb.lsa.umich.edu -C -D8000 $COMMONARG $KEYFILE

/usr/local/bin/autossh -M $(($RandomPort)) -f galaxy@lab.luo-lab.org $COMMONARG $KEYFILE \
-L8083:192.168.0.83:22 -L8059:192.168.0.83:5900 -L8005:192.168.0.5:22 -L8165:192.168.0.165:22 \
-L8003:192.168.0.3:22 -L8004:192.168.0.3:2211 -L20548:192.168.0.3:548 -L5000:192.168.0.3:5000 \
-L8202:192.168.0.202:443 -L8881:192.168.0.1:443 -R9922:localhost:22 -D8632

# ps -ef|grep autossh|awk '{print $2}'|xargs kill
# ps -ef|grep ssh
