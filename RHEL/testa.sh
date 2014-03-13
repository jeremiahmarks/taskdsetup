#!/usr/bin/env bash

NEEDED=8
CMAKEVER=$(cmake --version | awk '/cmake/ { print substr($3,3,1) }')
if [ "$CMAKEVER" -ge "$NEEDED" ]
then
	CM=cmake
	
else

	CMAKE28INSTALLED=$(rpm -qa | grep cmake28)
	
	if [ -z "$CMAKE28INSTALLED" ];
	then
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

