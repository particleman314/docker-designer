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
## @Software Package : Docker Image Generator (Ubuntu OS binding)
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

__record_addon_variables()
{
  typeset filename="$1"
  \cat <<-EOD >> "${filename}"
ENV ${ENV_SETTINGS}

EOD
  return 0
}

__record_components()
{
  typeset filename="$1"
  \cat <<-EOD >> "${filename}"
##############################################################################
# Install a binary version of requested applications
##############################################################################
COPY components/* /tmp/

EOD
  return 0
}

__record_copyfrom()
{
  typeset filename="$1"
  typeset subimage_id="$2"
  typeset home="$3"

  \cat <<-EOD >> "${filename}"
COPY --from=${subimage_id} ${home} /opt/
EOD
  return 0
}
__record_footer()
{
  typeset filename="$1"
  \cat <<-EOD >> "${filename}"
##############################################################################
# Define the entrypoint now for the container
##############################################################################
ENTRYPOINT [ "synopsys_setup.sh" ]
EOD
  return 0
}

__record_header()
{
  typeset filename="$1"
  \cat <<-EOD >> "${filename}"
FROM ubuntu:${UBUNTU_VERSION}
##############################################################################
# Setup arguments used within the Dockerfile for image generation
##############################################################################
LABEL vendor='Synopsys' \\
      maintainer='Mike Klusman' \\
      maintainer_email='klusman@synopsys.com'

##############################################################################
# Download base packages for installation
##############################################################################
RUN echo "[ INFO  ] Ubuntu Version = ${UBUNTU_VERSION}" && sleep 1; \\
    apt-get update; \\
    apt-get install -y ${UBUNTU_PACKAGES}

ENV ${ENV_UBUNTU}

EOD
  return 0
}

prepare_docker_contents()
{
  typeset RC=0
  typeset filename="$1"
  [ -z "${filename}" ] && return 1

  manage_docker_image "ubuntu:${UBUNTU_VERSION}"
  RC=$?
  if [ "${RC}" -ne 0 ]
  then
    \docker pull "ubuntu:${UBUNTU_VERSION}"
    RC=$?
    [ "${RC}" -ne 0 ] && return "${RC}"
  fi

  ### If SINGLE or COMPOSITE BUILD (single image created)
  if [ "${BUILD_TYPE}" -eq 1 ] || [ "${BUILD_TYPE}" -eq 2 ]
  then
    __record_header "${filename}"
    [ -n "${ENV_SETTINGS}" ] && __record_addon_variables "${filename}"
    [ "${DOCKER_COMPONENTS}" -ge 1 ] && __record_components "${filename}"

    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
    typeset comp=

    for comp in ${components}
    do
      comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
      typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"

      typeset version=
      eval "version=\${${upcomp}_VERSION}"
      \cat "${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}/${version}/DockerSubcomponent_${comp}" >> "${filename}"
      \rm -f "${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}/${version}/DockerSubcomponent_${comp}"
    done
  else
    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
    typeset comp=

    for comp in ${components}
    do
      comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
      typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"

      typeset version=
      eval "version=\${${upcomp}_VERSION}"
      \cat "${DOCKERFILE_LOCATION}/${comp}/${DOCKERFILE_GENERATED_NAME}/Dockerfile" >> "${filename}"
      \rm -f "${DOCKERFILE_LOCATION}/${comp}/${DOCKERFILE_GENERATED_NAME}/Dockerfile"
    done

    __record_header "${filename}"

    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep 'OS:' )"

    if [ -n "${components}" ]
    then
      typeset comp="$( printf "%s\n" "${components}" | \cut -f 2 -d ':' )"
      typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"

      typeset home=
      eval "home=\${${upcomp}_HOME}"
      typeset subimage_id="$( printf "%s\n" ${DOCKER_SUBIMAGE_MAPPING} | \grep "^${comp}" | \cut -f 2 -d ':' )"

      __record_copyfrom "${filename}" "${subimage_id}" "${home}"
    fi
  fi

  [ "${DOCKER_COMPONENTS}" -ge 1 ] && __record_footer "${filename}"

  return "${RC}"
}

write_dockerfile_ubuntu()
{
  typeset RC=0
  typeset version="$1"

  typeset OUTPUT_DIR=
  if [ "${BUILD_TYPE}" -eq 1 ]
  then
    OUTPUT_DIR="${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}/${version}"
  else
    OUTPUT_DIR="${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}"
  fi
  \mkdir -p "${OUTPUT_DIR}"
  typeset outputfile="${OUTPUT_DIR}/Dockerfile"
  \rm -f "${outputfile}"

  #############################################################################
  # Single source Dockerfile build
  #############################################################################
  [ "${BUILD_TYPE}" -eq 1 ] && DOCKER_IMAGE_ORDER+="SINGLE:${outputfile}"

  prepare_docker_contents "${outputfile}"
  RC=$?

  unset prepare_docker_contents
  unset __SOFTWARE

  DOCKERFILE="${outputfile}"
  return "${RC}"
}
