#!/usr/bin/env bash

#!/usr/bin/env bash
###############################################################################
###############################################################################
####
#### Author				Jeremiah Marks
#### Authors Contact:	Jeremiah@jlmarks.org
#### Authors website: 	jlmarks.org
#### 
#### Purpose:			This script is desig
		####	1.	Meet the requirements install taskwarrior and task server
		####	2.	Install taskwarrior and taskserver 
		####	3.	Set up taskserver in such a way that it starts at startup
		####			of the computer system
		####	4.	Set up the server and local client to work together
		####	5.	Set up the server to work with Mirakel
		####	6.	Generate a .taskdconfig file to import into Mirakel
		####	7. 	Create a backup of files needed to set up other taskwarrior
		####			installs to work with the taskserver
		####	8. cleanup after itself
####
####
#### Additional Notes:	
	####
	####	I intermittently run into issues where the systems cmake 2.8 or
	####		greater in order to cmake task and taskd. Since this is only
	####		an intermittent issue where it sometimes works and sometimes
	####		does not, I intend to 
	####	Don't forget to update the "server" line of your
	#### 		taskdconfig file to point back at the actual server rather than just
	#### 		"localhost". More than likely this will be either an IP address or a 
	#### 		hostname.
	####
	####	Don't hesitate to contact me if it doesn't work. If you can't get it to work
	####		chances are I cannot either, but who knows.
###############################################################################
###############################################################################

# The MIT License (MIT)

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


sudo yum update
sudo yum groupinstall -y "Development Tools"
sudo yum install -y gnutls-devel* 
sudo yum install -y libuuid-devel* 
sudo yum install -y gnutls-utils* 
sudo yum install -y wget 
sudo yum install -y cmake

####
#### Make sure to get this portion back from testa.sh where it is being refined. 
NEEDED=8
CMAKEVER=$(cmake --version | awk '/cmake/ { print substr($3,3,1) }')
if [ "$CMAKEVER" -ge "$NEEDED" ]
then
	CM=cmake
	
else

	CMAKE28INSTALLED=$(rpm -qa | grep cmake28)
	
	if [ -z "$CMAKE28INSTALLED" ];
	then
		CM=cmake28
		mkdir ~/cmaketemp
		cd ~/cmaketemp
		wget http://www.cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz
		tar -zxf cmake-2.8.12.2.tar.gz 
		cd cmake-2.8.12.2
		./configure 
		gmake 
		sudo gmake install
		cd $HOME
		rm -Rf $HOME/cmaketemp
	fi
fi

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
#taskd.conf and taskd are both needed to make the server automatically start on boot up. 

wget https://raw.github.com/jeremiahmarks/taskdsetup/master/debianOSs/taskd.conf
wget https://raw.github.com/jeremiahmarks/taskdsetup/master/debianOSs/taskd

sudo mv taskd.conf /etc/init/taskd.conf
sudo chown root:root /etc/init/taskd.conf

sudo mv taskd /etc/init.d/taskd
sudo chown root:root /etc/init.d/taskd
sudo chmod 755 /etc/init.d/taskd
sudo update-rc.d -f taskd defaults
sudo chkconfig --add taskd
sudo chkconfig --level 2345 taskd on


cd ..
rmdir temp-files

#cmake, make, and make install taskd and task

cd $HOME/.task/taskd
cmake .
make
sudo make install

cd $HOME/.task/task
cmake .
make
sudo make install

cd $HOME/.task/taskd
taskd init

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
