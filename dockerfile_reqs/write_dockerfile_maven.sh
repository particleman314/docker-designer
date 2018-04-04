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
## @Software Package : Docker Image Generator (Maven binding)
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

__IMAGE_BINARY_DIR="${__CURRENT_DIR}/binaries/apache-maven"
__SOFTWARE='Apache-Maven'

check_maven_settings()
{
  MAVEN_VERSION="${MAVEN_VERSION:-${__DEFAULT_MAVEN_VERSION}}"

  if [ -z "${MAVEN_VERSION}" ]
  then
    __record 'ERROR' 'Need to define MAVEN_VERSION environment variable to continue!'
    return 1
  fi

  return 0
}

prepare_docker_contents()
{
  typeset RC=0
  typeset COMPONENT_DIR="${1:-${OUTPUT_DIR}}"

  if [ ! -d "${__IMAGE_BINARY_DIR}" ]
  then
    printf "%s\n" "[ ERROR ] Unable to find necessary components for installation of ${__SOFTWARE} ${MAVEN_VERSION}!"
    return 1
  fi

  typeset mvnfile="apache-maven-${MAVEN_VERSION}-bin.tar.gz"

  typeset more_tries=1
  while [ "${more_tries}" -gt 0 ] && [ ! -f "${__IMAGE_BINARY_DIR}/${mvnfile}" ]
  do
    __record 'WARN' "Unable to find requested ${__SOFTWARE} ${MAVEN_VERSION}"
    __record 'INFO' "Looking to download from distribution site..."
    \sleep 1

    typeset download_filename="${mvnfile}"
    \curl -sI "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${download_filename}" | \grep HTTP | \grep -q 200
    if [ $? -eq 0 ]
    then
      \curl -sLk "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${download_filename}" -o "${__IMAGE_BINARY_DIR}/${download_filename}"
    else
      __record 'ERROR' "Cannot find necessary component file for installation of ${__SOFTWARE} ${MAVEN_VERSION}"
      RC=1
      return "${RC}"
    fi
    more_tries=$(( more_tries - 1 ))
  done

  if [ ! -f "${__IMAGE_BINARY_DIR}/${mvnfile}" ]
  then
    __record 'ERROR' "Cannot find all necessary components for installation of ${__SOFTWARE} ${MAVEN_VERSION}"
    RC=1
    return "${RC}"
  fi

  \mkdir -p "${COMPONENT_DIR}/components"
  \cp -f "${__IMAGE_BINARY_DIR}/${mvnfile}" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/${mvnfile}"

  \cp -f "${__CURRENT_DIR}/installation_files/install_maven.sh" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/install_maven.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup_maven.sh" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/synopsys_setup_maven.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/synopsys_setup.sh" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/synopsys_setup.sh"

  \cp -f "${__CURRENT_DIR}/setup_files/dependency.dat" "${COMPONENT_DIR}/components"
  record_cleanup "${COMPONENT_DIR}/components/dependency.dat"

  return "${RC}"
}

write_dockerfile_maven()
{
  typeset version="$1"
  typeset RC=0

  check_maven_settings
  RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  if [ "${BUILD_TYPE}" -ne 2 ]
  then
    [ "${BUILD_TYPE}" -eq 4 ] && DOCKER_SUBIMAGE_MAPPING+=" maven:${CURRENT_IMAGE_ID}"
    OUTPUT_DIR="${DOCKERFILE_LOCATION}/maven/${DOCKERFILE_GENERATED_NAME}/${version}"
    
    DOCKERFILE="${OUTPUT_DIR}/Dockerfile"
    \mkdir -p "${OUTPUT_DIR}"
    [ "${BUILD_TYPE}" -ne 4 ] && \rm -f "${DOCKERFILE}"

    . "${__CURRENT_DIR}/dockerfile_reqs/write_dockerfile_ubuntu.sh"

    __record_ubuntu_header "${DOCKERFILE}"
    __record_ubuntu_environment "${DOCKERFILE}"

    [ "${BUILD_TYPE}" -eq 4 ] \
      && __record_addon_variables "${DOCKERFILE}" "${ENV_SETTINGS_MAVEN}" \
      || __record_addon_variables "${DOCKERFILE}"

    __record_components "${DOCKERFILE}"

    write_dockerfile_body "${DOCKERFILE}"

    if [ "${BUILD_TYPE}" -eq 4 ]
    then
      prepare_docker_contents "${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}__${DOCKER_CONTAINER_VERSION}/${UBUNTU_VERSION}/${DOCKER_ARCH}"
      RC=$?
      printf "\n%s\n\n" "### --------------------------------------------- ###" >> "${DOCKERFILE}"

      unset __SOFTWARE
      unset __IMAGE_BINARY_DIR
      unset OUTPUT_DIR
      unset write_dockerfile_body
      unset prepare_docker_contents
      CURRENT_IMAGE_ID=$(( CURRENT_IMAGE_ID + 1 ))
    else
      __record_ubuntu_footer "${DOCKERFILE}"
      prepare_docker_contents
      RC=$?
    fi
  else
    OUTPUT_DIR="${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}/${version}/${DOCKER_ARCH}"
    DOCKERFILE="${OUTPUT_DIR}/DockerSubcomponent_maven"
    \mkdir -p "${OUTPUT_DIR}"
    \rm -f "${OUTPUT_DIR}/DockerSubcomponent_maven"

    write_dockerfile_body "${DOCKERFILE}"
    prepare_docker_contents
    RC=$?
  fi

  return "${RC}"
}

write_dockerfile_body()
{
  typeset dckfl="$1"

  \cat <<-EOD >> "${dckfl}"
##############################################################################
# Begin the installation process
##############################################################################
RUN echo "[ INFO  ] Apache-Maven Version = ${MAVEN_VERSION}" && sleep 1;\\
    /tmp/install_maven.sh; \\
    rm /tmp/install_maven.sh

EOD
  return 0
}
