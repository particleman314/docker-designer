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
## @Software Package : Docker Image Generator (Ant binding)
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.4
#
###############################################################################

if [ -n "${ENABLE_DETAILS}" ] && [ "${ENABLE_DETAILS}" -eq 1 ]
then
  set -x 
else
  ENABLE_DETAILS=0
  export ENABLE_DETAILS
fi

__DEFAULT_ANT_VERSION=1.9.11

__IMAGE_BINARY_DIR="${__CURRENT_DIR}/ANT_binaries"
__SOFTWARE='Apache-Ant'

build_ant_image()
{
  __TOP_LEVEL="$( \dirname "${__CURRENT_DIR}" )"
  __CLEANUP_FILE="${__TOP_LEVEL}/.cleanup"

  typeset RC=0

  if [ ! -d "${__TOP_LEVEL}/ant" ]
  then
    printf "%s\n" "[ ERROR ] Wrong level to generate ${__SOFTWARE} docker image"
    return 1
  fi

  pushd "${__TOP_LEVEL}" >/dev/null 2>&1

  prepare_docker_contents
  RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  typeset DOCKER_DEPENDENT_TAG="${__DOCKER_DEPENDENT_TAG:-syn_ubuntu:16.04}"
  typeset DOCKER_GENERATE_TAG="syn_ant_ubu1604:${ANT_VERSION}"

  manage_docker_image "${DOCKER_DEPENDENT_TAG}"
  RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  popd >/dev/null 2>&1

  \docker build --tag "${DOCKER_GENERATE_TAG}" .
  RC=$?

  [ "${RC}" -ne 0 ] && printf "%s\n" "[ ERROR ] Problem with generation of docker image of ${__SOFTWARE} to be tagged --> ${DOCKER_GENERATE_TAG}"

  cleanup
  return "${RC}"
}

check_ant_settings()
{
  ANT_VERSION="${ANT_VERSION:-${__DEFAULT_ANT_VERSION}}"

  if [ -z "${ANT_VERSION}" ]
  then
    __record 'ERROR' 'Need to define ANT_VERSION environment variable to continue!'
    return 1
  fi

  return 0
}

manage_docker_image()
{
  typeset request_image="$1"

  \docker images --format "{{.Repository}}:{{.Tag}}" | \grep -q "${request_image}"
  typeset RC=$?

  [ "${RC}" -ne 0 ] && __record 'ERROR' "Requested base image << ${request_image} >> not found in local docker repository!"

  return "${RC}"
}

prepare_ant_content()
{
  check_ant_settings
  [ $? -ne 0 ] && return 1

  \mkdir -p "${__CURRENT_DIR}/ant"

  prepare_docker_contents
  RC=$?
  return "${RC}"
}

prepare_docker_contents()
{
  typeset RC=0

  if [ ! -d "${__IMAGE_BINARY_DIR}" ]
  then
    printf "%s\n" "[ ERROR ] Unable to find necessary components for installation of ${__SOFTWARE} ${ANT_VERSION}!"
    return 1
  fi

  typeset antfile="apache-ant-${ANT_VERSION}-bin.tar.gz"

  typeset more_tries=1
  while [ "${more_tries}" -gt 0 ] && [ ! -f "${__IMAGE_BINARY_DIR}/${antfile}" ]
  do
    __record 'WARN' "Unable to find requested ${__SOFTWARE} ${ANT_VERSION}"
    __record 'INFO' "Looking to download from distribution site..."
    \sleep 1

    typeset download_filename="${antfile}"
    \curl -Lk "https://archive.apache.org/dist/ant/binaries/${download_filename}" -o "${__IMAGE_BINARY_DIR}/${download_filename}"
    more_tries=$(( more_tries - 1 ))
  done

  if [ ! -f "${__IMAGE_BINARY_DIR}/${antfile}" ]
  then
    __record 'ERROR' "Cannot find all necessary components for installation of ${__SOFTWARE} ${ANT_VERSION}"
    RC=1
    return "${RC}"
  fi

  \mkdir -p "${OUTPUT_DIR}/components"
  \cp -f "${__IMAGE_BINARY_DIR}/${antfile}" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/${antfile}"

  \cp -f "${__CURRENT_DIR}/installation_files/install_ant.sh" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/install_ant.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup_ant.sh" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/synopsys_setup_ant.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup.sh" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/synopsys_setup.sh"

  [ -n "${ANT_SLAVE}" ] && [ "${ANT_SLAVE}" -ne 1 ] && cleanup

  return "${RC}"
}

write_dockerfile_ant()
{
  if [ -n "${ANT_SLAVE}" ] && [ "${ANT_SLAVE}" -eq 1 ]
  then
    OUTPUT_DIR="${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}"
  else
    OUTPUT_DIR="${DOCKERFILE_LOCATION}/ant/${DOCKERFILE_GENERATED_NAME}"
  fi
  cat <<-EOD >> ${OUTPUT_DIR}/Dockerfile
##############################################################################
# Define the content necessary to handle ant
##############################################################################
ENV ANT_VERSION=${ANT_VERSION} \\
    ANT_HOME=${ANT_HOME}

EOD
  if [ "${DOCKER_COMPONENTS}" -le 1 ]
  then
    cat <<-EOD >> ${OUTPUT_DIR}/Dockerfile
##############################################################################
# Install a binary version of Apache-Ant ${ANT_VERSION}
##############################################################################
COPY components/* /tmp/

EOD
  fi
  cat <<-EOD >> ${OUTPUT_DIR}/Dockerfile
##############################################################################
# Begin the installation process
##############################################################################
RUN echo "[ INFO  ] Apache-Ant Version = ${ANT_VERSION}" && sleep 1; \\
    /tmp/install_ant.sh; \\
    rm /tmp/install_ant.sh

EOD

  prepare_ant_content

  unset prepare_docker_contents
  unset prepare_ant_content

  unset __SOFTWARE
  unset __IMAGE_BINARY_DIR
  unset OUTPUT_DIR
  unset ANT_SLAVE

  return $?
}

[ -z "${ANT_SLAVE}" ] || [ "${ANT_SLAVE}" -ne 1 ] && build_ant_image
