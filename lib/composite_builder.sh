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
## @Software Package : Docker Image Generator (Single/Multistage Support)
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.23
#
###############################################################################

if [ -n "${ENABLE_DETAILS}" ] && [ "${ENABLE_DETAILS}" -eq 1 ]
then
  set -x 
else
  ENABLE_DETAILS=0
  export ENABLE_DETAILS
fi

run_docker_build_composite()
{
  typeset RC=0
  printf "%s\n" "Building stages..."

  #typeset counter=1
  typeset image

  for image in ${DOCKER_SUBIMAGE_MAPPING}
  do
  	typeset image_type="$( printf "%s\n" "${image}" | \cut -f 1 -d ':' )"
    #printf "\t%d) %s\n" "${counter}" "${image_type}"

    . "${__PROGRAM_DIR}/lib/docker_builders/${image_type}_docker_builder.sh" "${image}"
    RC=$(( RC + $? ))
    #ßcounter=$(( counter + 1 ))
  done

  return "${RC}"
}

run_docker_build_composite