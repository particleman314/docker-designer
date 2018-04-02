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
## @Software Package : Synopsys Tool Setup (Apache-Ant)
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.01
#
###############################################################################

# Verify all exports and path components necessary

\which 'ant' >/dev/null 2>&1

if [ $? -ne 0 ]
then
  if [ -z "${JAVA_HOME}" ]
  then
    printf "%s\n" "[ ERROR ] Unable to determine JAVA location necessary for Apache-Ant."
    printf "%s\n" "[ ERROR ]    It may not function as expected!"
  else
  	\which 'java' >/dev/null 2>&1

  	[ $? -ne 0 ] && [ -f "${__ENTRYPOINT_DIR}/synopsys_setup_java.sh" ] && \
  	   . "${__ENTRYPOINT_DIR}/synopsys_setup_java.sh"
  	   
    if [ -n "${ANT_HOME}" ]
    then
      PATH="${ANT_HOME}/bin:${PATH}"
      export PATH
    fi
  fi
fi