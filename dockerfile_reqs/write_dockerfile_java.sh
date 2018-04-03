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

prepare_docker_contents()
{
  typeset RC=0
  typeset COMPONENT_DIR="${1:-${OUTPUT_DIR}}"

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

  \mkdir -p "${COMPONENT_DIR}/components"
  \cp -f "${__IMAGE_BINARY_DIR}/${matched_file}" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/${matched_file}"

  \cp -f "${__CURRENT_DIR}/installation_files/install_java.sh" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/install_java.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup_java.sh" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/synopsys_setup_java.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup.sh" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/synopsys_setup.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/dependency.dat" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/dependency.dat"

  return "${RC}"
}

write_dockerfile_java()
{
  typeset version="$1"
  typeset outputfile=
  typeset RC=0

  check_java_settings
  RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  if [ "${BUILD_TYPE}" -eq 1 ]
  then
    OUTPUT_DIR="${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}/${version}"
    \mkdir -p "${OUTPUT_DIR}"

    write_dockerfile_body "${OUTPUT_DIR}/DockerSubcomponent_java"
    prepare_docker_contents
    RC=$?
  else
    DOCKER_SUBIMAGE_MAPPING+=" java:${CURRENT_IMAGE_ID}"
    CURRENT_IMAGE_ID=$(( CURRENT_IMAGE_ID + 1 ))

    OUTPUT_DIR="${DOCKERFILE_LOCATION}/java/${DOCKERFILE_GENERATED_NAME}/${version}"
    outputfile="${OUTPUT_DIR}/Dockerfile"
    \mkdir -p "${OUTPUT_DIR}"
    \rm -f "${outputfile}"

    . "${__CURRENT_DIR}/dockerfile_reqs/write_dockerfile_ubuntu.sh"

    __record_ubuntu_header "${outputfile}"
    __record_ubuntu_environment "${outputfile}"
    __record_addon_variables "${outputfile}" "${ENV_SETTINGS_JAVA}"
    __record_components "${outputfile}"
    write_dockerfile_body "${outputfile}"

    prepare_docker_contents "${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}/${UBUNTU_VERSION}"
    RC=$?
    printf "\n%s\n\n" "### --------------------------------------------- ###" >> "${outputfile}"
  fi

  unset __SOFTWARE
  unset __IMAGE_BINARY_DIR
  unset OUTPUT_DIR
  unset write_dockerfile_body
  unset prepare_docker_contents

  return "${RC}"
}

write_dockerfile_body()
{
  typeset dckfl="$1"

  \cat <<-EOD >> "${dckfl}"
##############################################################################
# Begin the installation process
##############################################################################
RUN echo "[ INFO  ] Oracle JDK Version = ${JAVA_VERSION}" && sleep 1;\\
    /tmp/install_java.sh; \\
    rm /tmp/install_java.sh

EOD
  return 0
}
