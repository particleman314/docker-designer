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
## @Software Package : Docker Image Generator (Java binding)
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.8
#
###############################################################################

if [ -n "${ENABLE_DETAILS}" ] && [ "${ENABLE_DETAILS}" -eq 1 ]
then
  set -x 
else
  ENABLE_DETAILS=0
  export ENABLE_DETAILS
fi

__IMAGE_BINARY_DIR="${__CURRENT_DIR}/${__DEFAULT_JAVA_BINARY_STORE}"
__SOFTWARE='Oracle-JDK'

build_java_image()
{
  if [ "${BUILD_TYPE}" -eq 1 ]
  then
    __TOP_LEVEL="$( \dirname "${__CURRENT_DIR}" )"
    __CLEANUP_FILE="${__TOP_LEVEL}/.cleanup"
  else
    __TOP_LEVEL="${__CURRENT_DIR}"
  fi

  typeset RC=0

  if [ ! -d "${__TOP_LEVEL}/java" ]
  then
    printf "%s\n" "[ ERROR ] Wrong level to generate ${__SOFTWARE} docker image"
    return 1
  fi

  pushd "${__TOP_LEVEL}" >/dev/null 2>&1

  prepare_docker_contents
  RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  typeset DOCKER_DEPENDENT_TAG="${__DOCKER_DEPENDENT_TAG:-syn_ubuntu:16.04}"
  typeset DOCKER_GENERATE_TAG="syn_java_ubu1604:${JAVA_VERSION}"

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

check_java_settings()
{
  JAVA_VERSION="${JAVA_VERSION:-${__DEFAULT_JAVA_VERSION}}"

  if [ -z "${JAVA_VERSION}" ]
  then
    __record 'ERROR' 'Need to define JAVA_VERSION environment variable to continue!'
    return 1
  fi

  JAVA_MAJOR_VERSION="${JAVA_MAJOR_VERSION}"
  [ -z "${JAVA_MAJOR_VERSION}" ] && JAVA_MAJOR_VERSION="$( printf "%s\n" "${JAVA_VERSION}" | \cut -f 2 -d '.' )"
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

prepare_java_content()
{
  check_java_settings
  [ $? -ne 0 ] && return 1

  \mkdir -p "${__CURRENT_DIR}/java"

  prepare_docker_contents
  RC=$?
  return "${RC}"
}

prepare_docker_contents()
{
  typeset RC=0

  if [ ! -d "${__IMAGE_BINARY_DIR}" ]
  then
    __record 'ERROR' "Unable to find necessary components for installation of ${__SOFTWARE} ${JAVA_VERSION}!"
    return 1
  fi

  typeset matched_file="$( \find "${__IMAGE_BINARY_DIR}" -maxdepth 1 -type f -name "jdk-${JAVA_MAJOR_VERSION}*.tar.gz" -exec \basename "{}" \; )"
  typeset more_tries=1
  while [ "${more_tries}" -gt 0 ] && [ -n "${matched_file}" ] && [ ! -f "${__IMAGE_BINARY_DIR}/${matched_file}" ]
  do
    __record 'WARN' "Unable to find requested ${__SOFTWARE} ${JAVA_VERSION}"
    __record 'INFO' 'Looking to download from distribution site...'
    \sleep 1

    #typeset download_filename="apache-ant-${ANT_VERSION}-bin.tar.gz"
    #\curl -fsLk "https://archive.apache.org/dist/ant/binaries/${download_filename}" -o "${__IMAGE_BINARY_DIR}/${download_filename}"
    matched_file="$( \find "${__IMAGE_BINARY_DIR}" -maxdepth 1 -type f -name "jdk-${JAVA_MAJOR_VERSION}*.tar.gz" -exec \basename "{}" \; )"
    more_tries=$(( more_tries - 1 ))
  done

  if [ ! -f "${__IMAGE_BINARY_DIR}/${matched_file}" ]
  then
    __record 'ERROR' "Cannot find all necessary components for installation of ${__SOFTWARE} ${JAVA_VERSION}"
    RC=1
    return "${RC}"
  fi

  \mkdir -p "${OUTPUT_DIR}/components"
  \cp -f "${__IMAGE_BINARY_DIR}/${matched_file}" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/${matched_file}"

  \cp -f "${__CURRENT_DIR}/installation_files/install_java.sh" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/install_java.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup_java.sh" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/synopsys_setup_java.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup.sh" "${OUTPUT_DIR}/components"
  record_cleanup "${OUTPUT_DIR}/components/synopsys_setup.sh"

  [ "${JAVA_COMPOSITE}" -eq 0 ] && [ "${JAVA_MULTISTAGE}" -eq 0 ] && cleanup

  return "${RC}"
}

copy_components()
{
  typeset outputfile="$1"
  \cat <<-EOD >> "${outputfile}"
##############################################################################
# Install a binary version of JDK ${JAVA_VERSION}
##############################################################################
COPY components/* /tmp/

EOD
  return 0
}

write_dockerfile_java()
{
  typeset outputfile=

  if [ "${BUILD_TYPE}" -eq 1 ]
  then
    typeset OUTPUT_DIR="${DOCKERFILE_LOCATION}/java/${DOCKERFILE_GENERATED_NAME}"
    outputfile="${OUTPUT_DIR}/Dockerfile"
    build_java_image "${outputfile}"
    return $?
  else
    typeset OUTPUT_DIR="${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}"
    outputfile="${OUTPUT_DIR}/DockerSubcomponent_java"
    \rm -f "${outputfile}"
  fi

  \cat <<-EOD >> "${outputfile}"
##############################################################################
# Begin the installation process
##############################################################################
RUN echo "[ INFO  ] Oracle JDK Version = ${JAVA_VERSION}" && sleep 1;\\
    /tmp/install_java.sh; \\
    rm /tmp/install_java.sh

EOD

  prepare_java_content

  unset prepare_docker_contents
  unset prepare_java_content

  unset __SOFTWARE
  unset __IMAGE_BINARY_DIR
  unset OUTPUT_DIR

  return $?
}
