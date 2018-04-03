#!/usr/bin/env bash

###############################################################################
# Copyright (c) 2018.  All rights reserved. 
# Mike Klusman IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A 
# COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS 
# ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, APPLICATION OR 
# STANDARD, Mike Klusman IS MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION 
# IS FREE FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE 
# FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION. 
# Mike Klusman EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO 
# THE ADEQUACY OF THE IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO 
# ANY WARRANTIES OR REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE 
# FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY 
# AND FITNESS FOR A PARTICULAR PURPOSE. 
###############################################################################

###############################################################################
#
## @Author           : Mike Klusman
## @Software Package : Docker Image Generator (Apache-Ant Support)
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.56
#
###############################################################################

if [ "$1" == 'default' ]
then
  __input="${__DEFAULT_ANT_VERSION}:${__DEFAULT_ANT_HOME}"
else
  __input="$1"
fi

ANT_VERSION="$( printf "%s\n" "${__input}" | \cut -f 1 -d ':' )"
ANT_HOME="$( printf "%s\n" "${__input}" | \cut -f 2 -d ':' )"
[ "${ANT_HOME}" == "${ANT_VERSION}" ] && ANT_HOME="${__DEFAULT_ANT_HOME}"

ENV_SETTINGS_ANT='ANT_VERSION ANT_HOME'
add_environment_setting 'ANT_VERSION' 'ANT_HOME'
