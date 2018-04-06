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
 
run_docker_build()
{
  if [ $# -lt 1 ]
  then
    __record 'ERROR' "No dockerfile requested to be processed!"
    return 1
  fi

  typeset dockerfilename="$1"
  if [ ! -f "${dockerfilename}" ]
  then
    __record 'ERROR' "Requested dockerfile for container compilation does NOT exist!"
    return 1
  fi

  if [ -z "${DOCKERFILE_GENERATED_NAME}" ] || [ -z "${DOCKER_CONTAINER_VERSION}" ]
  then
    __record 'ERROR' "Container name and/or version are NOT set!"
    return 1
  fi

  typeset dockerfiledir="$( \dirname "${dockerfilename}" )"

  \docker build ${DOCKER_QUIET_FLAG} --tag ${DOCKERFILE_GENERATED_NAME}:${DOCKER_CONTAINER_VERSION} --force-rm --file "${dockerfiledir}/Dockerfile" "${dockerfiledir}"
  typeset RC=$?

  if [ "${RC}" -eq 0 ]
  then
    __record 'INFO' 'Providing image from docker for upload/distribution...'

    \docker save --output "${dockerfiledir}/${DOCKERFILE_GENERATED_NAME}-${DOCKER_CONTAINER_VERSION}.tar" ${DOCKERFILE_GENERATED_NAME}:${DOCKER_CONTAINER_VERSION}
    RC=$?

    if [ "${RC}" -eq 0 ]
    then
      \gzip -f "${dockerfiledir}/${DOCKERFILE_GENERATED_NAME}-${DOCKER_CONTAINER_VERSION}.tar"
      __record 'INFO' "Image can be found at --> ${dockerfiledir}/${DOCKERFILE_GENERATED_NAME}-${DOCKER_CONTAINER_VERSION}.tar.gz"
    else
      __record 'ERROR' "Unable to extract required image from local docker registry"
    fi
  else
    __record 'ERROR' "Issue encountered generating image for ${DOCKERFILE_GENERATED_NAME}:${DOCKER_CONTAINER_VERSION}"
    __record 'WARN' 'Cleanup needed for stale docker images and stale Dockerfiles'
  fi

  return "${RC}"
}

run_docker_build $@