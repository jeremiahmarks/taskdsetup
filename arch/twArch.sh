#!/usr/bin/env bash

sudo pacman -S wget
sudo pacman -S git
sudo pacman -S cmake


mkdir -p $HOME/.task
cd $HOME/.task

#placing the taskserver data in /var/taskserver seems like an appropriate choice since apache keeps its data
export TASKDDATA=/var/taskserver
sudo mkdir -p $TASKDDATA
sudo chown $USER:$USER -R $TASKDDATA

#These may change, but for now they are the correct download links for both
#task and taskd
git clone https://git.tasktools.org/scm/tm/task.git
git clone https://git.tasktools.org/scm/tm/taskd.git

#since I ran into issues with downloading a file name taskd into a folder where there is a folder named
#taskd I am using a tempfiles folder
mkdir temp-files
cd temp-files

wget https://raw.github.com/jeremiahmarks/taskdsetup/master/arch/taskd.service

sudo chown root:root taskd.service
sudo mv taskd.service /etc/systemd/system/taskd.service

################################################################################
################################################################################
####
#### from https://wiki.archlinux.org/index.php/Systemd

####Enable a unit to be started on bootup:
####
#### systemctl enable unit
sudo systemctl enable taskd

#### Reload systemd, scanning for new or changed units:

#### systemctl daemon-reload


cd ..
rmdir temp-filessudo


# #cmake, make, and make install taskd and task

cd taskd
cmake .
make
sudo make install

cd ../task
cmake .
make
sudo make install

cd ../taskd
taskd init

#This creates the various certs that you will need to authenticate back and forth.
cd pki
./generate

#copying the various certs into the servers area
cp client.cert.pem $TASKDDATA
cp client.key.pem  $TASKDDATA
cp server.cert.pem $TASKDDATA
cp server.key.pem  $TASKDDATA
cp server.crl.pem  $TASKDDATA
cp ca.cert.pem     $TASKDDATA

#initial configuration of taskd
taskd config --force client.cert $TASKDDATA/client.cert.pem
taskd config --force client.key $TASKDDATA/client.key.pem
taskd config --force server.cert $TASKDDATA/server.cert.pem
taskd config --force server.key $TASKDDATA/server.key.pem
taskd config --force server.crl $TASKDDATA/server.crl.pem
taskd config --force ca.cert $TASKDDATA/ca.cert.pem

cd $HOME/.task
taskd config --force log $PWD/taskd.log
taskd config --force pid.file $PWD/taskd.pid
taskd config --force server localhost:53589
taskd config --force ip.log 1
taskd config --force client.allow '^task [2-9],^taskd,^libtaskd,^Mirakel [1-9]'


# http://mirakel.azapps.de/scripts/add_user.sh
###########################################
##This is the start of a modified add_user.sh script from http://mirakel.azapps.de/scripts/add_user.sh
ROOT_CA=$HOME/.task/taskd/pki/ca.cert.pem

 
#read username and org from comandline
read -p "Username?`echo $'\n> '`" USER
read -p "Org?`echo $'\n> '`" ORG
#create org if nessersary
taskd add --data $TASKDDATA org $ORG >&2>/dev/null
#create user
taskd add --data $TASKDDATA user --quiet $ORG $USER 1> user.key
#find configs
taskd config --data $TASKDDATA |grep  '^server ' >server
SERVER=$(sed 's/server//g' server)
(cd $HOME/.task/taskd/pki && ./generate.client $ORG$USER)
cd $PWD
cp $HOME/.task/taskd/pki/$ORG$USER.cert.pem $USER.cert
cat $HOME/.task/taskd/pki/$ORG$USER.key.pem |sed -n '/-----BEGIN RSA PRIVATE KEY-----/,/-----END RSA PRIVATE KEY-----/p' >$USER.key

#if user-config already exists remove it
rm -rf $USER.taskdconfig

#Write to user-conf file
echo "username: "$USER>>$USER.taskdconfig
echo "org: "$ORG>>$USER.taskdconfig
cat user.key| sed 's/New user key:/user key:/g'>>$USER.taskdconfig
echo "server: "`cat server| sed 's/^server//g'|sed 's/^[ \t]*//'`>>$USER.taskdconfig
echo "Client.cert:">>$USER.taskdconfig
cat $USER.cert>>$USER.taskdconfig
echo "Client.key:">>$USER.taskdconfig
cat $USER.key>>$USER.taskdconfig
echo "ca.cert:">>$USER.taskdconfig
cat $ROOT_CA>>$USER.taskdconfig

USERKEY=$(sed 's/New user key: //g' user.key)

#remove temp-files
rm -rf user.key server $USER.cert
rm -rf user.key server $USER.key

mv $USER.taskdconfig ~/$USER.taskdconfig


#####################################
mkdir ~/totar
touch ~/totar/credentials.txt
echo "$ORG/$USER/$USERKEY">>~/totar/credentials.txt
touch ~/totar/server.txt
echo "$SERVER">>~/totar/server.txt

cp $HOME/.task/taskd/pki/$ORG$USER.cert.pem ~/.task
cp $HOME/.task/taskd/pki/$ORG$USER.cert.pem ~/totar
cp $HOME/.task/taskd/pki/$ORG$USER.key.pem ~/.task
cp $HOME/.task/taskd/pki/$ORG$USER.key.pem ~/totar
cp $HOME/.task/taskd/pki/ca.cert.pem ~/.task
cp $HOME/.task/taskd/pki/ca.cert.pem ~/totar

cp ~/$USER.taskdconfig ~/totar/$USER.taskdconfig


task config taskd.certificate ~/.task/$ORG$USER.cert.pem
task config taskd.key         ~/.task/$ORG$USER.key.pem
task config taskd.credentials $ORG/$USER/$USERKEY
task config taskd.server      $SERVER
task config taskd.ca ~/.task/ca.cert.pem

taskdctl start

cp ~/.taskrc ~/totar

cd
tar cf ~/taskwarriorclientSettings.tar totar/

rm -Rf ~/totar
rm -Rf ~/.task/task
rm -Rf ~/.task/taskd

task sync initialize




echo "I have placed your taskdconfig file in your home directory. Copy it to your device in order to enable sync with mirakel."
echo "I have also placed a copy of all of your needed certifications an archive $USERclientSettings.tar . "
