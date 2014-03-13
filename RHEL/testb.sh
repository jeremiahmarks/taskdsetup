#!/usr/bin/env bash

#!/usr/bin/env bash
###############################################################################
###############################################################################
####
#### Author             Jeremiah Marks
#### Authors Contact:   Jeremiah@jlmarks.org
#### Authors website:   jlmarks.org
#### 
#### Purpose:           This script is desig
        ####    1.  Meet the requirements install taskwarrior and task server
        ####    2.  Install taskwarrior and taskserver 
        ####    3.  Set up taskserver in such a way that it starts at startup
        ####            of the computer system
        ####    4.  Set up the server and local client to work together
        ####    5.  Set up the server to work with Mirakel
        ####    6.  Generate a .taskdconfig file to import into Mirakel
        ####    7.  Create a backup of files needed to set up other taskwarrior
        ####            installs to work with the taskserver
        ####    8. cleanup after itself
####
####
#### Additional Notes:  
    ####
    ####    I intermittently run into issues where the systems cmake 2.8 or
    ####        greater in order to cmake task and taskd. Since this is only
    ####        an intermittent issue where it sometimes works and sometimes
    ####        does not, I intend to 
    ####    Don't forget to update the "server" line of your
    ####        taskdconfig file to point back at the actual server rather than just
    ####        "localhost". More than likely this will be either an IP address or a 
    ####        hostname.
    ####
    ####    Don't hesitate to contact me if it doesn't work. If you can't get it to work
    ####        chances are I cannot either, but who knows.
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
sudo yum groupinstall "Development Tools"
sudo yum install gnutls-devel* 
sudo yum install libuuid-devel* 
sudo yum install gnutls-utils* 
sudo yum install wget 
sudo yum install cmake

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
cd ..
rmdir temp-files

#cmake, make, and make install taskd and task
cd taskd
$CM .
make
sudo make install

cd ../task
$CM .
make
sudo make install
