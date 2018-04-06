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
## @Software Package : Docker Image Generator (Composite Ant Support)
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

build_maven()
{
  typeset image="$1"
  [ -z "$1" ] && return 1

  typeset image_type="$( printf "%s\n" "${image}" | \cut -f 1 -d ':' )"
  typeset up_image_type="$( printf "%s\n" "${image_type}" | \tr '[:lower:]' '[:upper:]' )"
  typeset version=
  eval "version=\${${up_image_type}_VERSION}"

  typeset RC=0
  typeset dckfl="$( printf "%s\n" " ${image}" | \cut -f 2 -d ':' )"
  typeset dckfldir="$( \dirname "${dckfl}" )"
  typeset dckbldid="syn_${image_type}:${version}"

  \docker build ${DOCKER_QUIET_FLAG} --tag "syn_${image_type}:${version}" --force-rm --file "${dckfl}" "${dckfldir}"
  RC=$?

  typeset copylocation="${__PROGRAM_DIR}/ubuntu/${DOCKERFILE_GENERATED_NAME}__${DOCKER_CONTAINER_VERSION}/${UBUNTU_VERSION}/${DOCKER_ARCH}/components"
  \mkdir -p "${copylocation}"

  pushd "${dckfldir}" > /dev/null 2>&1
  \docker container create --name "extract_${image_type}" "syn_${image_type}:${version}"

  typeset target_installation_dir="$( \dirname "${M2_HOME}" )/apache-maven-${MAVEN_VERSION}"

  \mkdir -p "${copylocation}/$( \basename "${target_installation_dir}" )"
  \docker container cp "extract_${image_type}:${target_installation_dir}/" "${copylocation}/$( \basename "${target_installation_dir}" )" 
  \docker container rm -f "extract_${image_type}"
  popd >/dev/null 2>&1
}

build_maven $@