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
## @Software Package : Docker Image Generator (Java Support)
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.56
#
###############################################################################

JAVA_VERSION="$( printf "%s\n" "$1" | \cut -f 1 -d ':' )"
JAVA_MAJOR_VERSION="$( printf "%s\n" "${JAVA_VERSION}" | \cut -f 2 -d '.' )"
JAVA_HOME="$( printf "%s\n" "$1" | \cut -f 2 -d ':' )"
[ "${JAVA_HOME}" == "${JAVA_VERSION}" ] && JAVA_HOME="${__DEFAULT_JAVA_HOME}"
JDK_HOME="${JAVA_HOME}"

ENV_SETTINGS_JAVA='JAVA_VERSION JAVA_MAJOR_VERSION JAVA_HOME JDK_HOME'
add_environment_setting 'JAVA_VERSION' 'JAVA_MAJOR_VERSION' 'JAVA_HOME' 'JDK_HOME'
