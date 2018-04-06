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
  typeset envvar_subset="$2"

  typeset ENV_SETTINGS_SUBSET=
  if [ -n "${envvar_subset}" ]
  then
    typeset evss=
    for evss in ${envvar_subset}
    do
      for es in ${ENV_SETTINGS}
      do
        printf "%s\n" "${es}" | \grep -q "${evss}"
        if [ $? -eq 0 ]
        then
          ENV_SETTINGS_SUBSET+=" ${es}"
          break
        fi
      done
    done
  fi

  if [ -n "${ENV_SETTINGS_SUBSET}" ]
  then
    \cat <<-EOD >> "${filename}"
ENV ${ENV_SETTINGS_SUBSET}

EOD
  else  
    \cat <<-EOD >> "${filename}"
ENV ${ENV_SETTINGS}

EOD
  fi
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

__record_ubuntu_body()
{
  typeset filename="$1"

  if [ -n "${DOCKER_QUIET_FLAG}" ]
  then
    \cat <<-EOD >> "${filename}"  
##############################################################################
# Download base packages for installation
##############################################################################
RUN apt-get update; \\
    apt-get install -y ${UBUNTU_PACKAGES}

EOD
  else
    \cat <<-EOD >> "${filename}"  
##############################################################################
# Download base packages for installation
##############################################################################
RUN echo "[ INFO  ] Ubuntu Version = ${UBUNTU_VERSION}" && sleep 1; \\
    apt-get update; \\
    apt-get install -y ${UBUNTU_PACKAGES}

EOD
  fi

  return 0
}

__record_ubuntu_copyfrom()
{
  typeset filename="$1"
  typeset subimage_id="$2"
  typeset sourcedir="$3"
  typeset targetdir="${4:-"/opt"}"

  \cat <<-EOD >> "${filename}"
COPY --from=${subimage_id} "${sourcedir}" "${targetdir}"
EOD
  return 0
}

__record_ubuntu_environment()
{
  typeset filename="$1"
  \cat <<-EOD >> "${filename}"  
##############################################################################
# Environmental Setup
##############################################################################
ENV ${ENV_UBUNTU}

EOD
  return 0
}

__record_ubuntu_footer()
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

__record_ubuntu_header()
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

EOD
  return 0
}

__record_ubuntu_install_composite()
{
  typeset filename="$1"

  if [ -n "${DOCKER_QUIET_FLAG}" ]
  then
    \cat <<-EOD >> "${filename}"  
##############################################################################
# Begin the installation process
##############################################################################
RUN /tmp/install_composite.sh; rm /tmp/install_composite.sh

EOD
  else
    \cat <<-EOD >> "${filename}"  
##############################################################################
# Begin the installation process
##############################################################################
RUN echo "[ INFO  ] Preparing prebuilt packages" && sleep 1; \\
    /tmp/install_composite.sh; \\
    rm /tmp/install_composite.sh

EOD
  fi

  return 0
}

__record_ubuntu_linkage()
{
  typeset filename="$1"
  typeset orig_tgt_dir="$2"
  typeset upcomp="$3"

  [ -z "${upcomp}" ] && return 0

  typeset home=
  typeset RUN_LINK=

  case "${upcomp}" in
  'MAVEN' )  eval "home=\${M2_HOME}"; RUN_LINK=" ln -s ${orig_tgt_dir} ${home};";;
  *       )  eval "home=\${${upcomp}_HOME}"; RUN_LINK=" ln -s ${orig_tgt_dir} ${home};";;
  esac

  if [ -n "${RUN_LINK}" ]
  then
    \cat <<-EOD >> "${filename}"  
##############################################################################
# Assign necessary links to allow for simplicity
##############################################################################
RUN ${RUN_LINK}

EOD
  fi

  return 0
}

prepare_ubuntu_docker_contents()
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
  if [ "${BUILD_TYPE}" -lt 4 ]
  then
    __record_ubuntu_header "${filename}"
    __record_ubuntu_body "${filename}"
    __record_ubuntu_environment "${filename}"
    [ -n "${ENV_SETTINGS}" ] && __record_addon_variables "${filename}"
    [ "${DOCKER_COMPONENTS}" -ge 1 ] && __record_components "${filename}"

    \mkdir -p "${OUTPUT_DIR}/components"
    if [ "${BUILD_TYPE}" -eq 3 ]
    then
      \cp -f "${__PROGRAM_DIR}/installation_files/install_composite.sh" "${OUTPUT_DIR}/components"
      __record_ubuntu_install_composite "${filename}"
    fi

    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
    typeset comp=

    for comp in ${components}
    do
      comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
      typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"

      typeset version=
      eval "version=\${${upcomp}_VERSION}"

      if [ "${BUILD_TYPE}" -eq 2 ]
      then
        \cat "${OUTPUT_DIR}/DockerSubcomponent_${comp}" >> "${filename}"
        \rm -f "${OUTPUT_DIR}/DockerSubcomponent_${comp}"
      else
        \cp -f "${__PROGRAM_DIR}/setup_files/synopsys_setup_${comp}.sh" "${OUTPUT_DIR}/components"
      fi

      typeset orig_install_dir=
      case "${upcomp}" in
      'MAVEN'  )  eval "home=\${M2_HOME}"; orig_install_dir="$( \dirname "${home}" )/apache-maven-${MAVEN_VERSION}";;
      'ANT'    )  eval "home=\${${upcomp}_HOME}"; orig_install_dir="$( \dirname "${home}" )/apache-ant-${ANT_VERSION}";;
      'JAVA'   )  eval "home=\${${upcomp}_HOME}"; orig_install_dir="$( \dirname "${home}" )/oracle-jdk-${JAVA_VERSION}";;
      esac
      #__record_ubuntu_linkage "${filename}" "${orig_install_dir}" "${home}"

      printf "%s\n" "${comp}:${home}:$( \basename "${orig_install_dir}" )" >> "${OUTPUT_DIR}/components/installation_drop.pkg"
    done

    \cp -f "${__PROGRAM_DIR}/setup_files/synopsys_setup.sh" "${OUTPUT_DIR}/components"
  else
    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
    typeset comp=

    for comp in ${components}
    do
      comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
      typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"

      typeset version=
      eval "version=\${${upcomp}_VERSION}"

      \cat "${DOCKERFILE_LOCATION}/${comp}/${DOCKERFILE_GENERATED_NAME}/${version}/${DOCKER_ARCH}/Dockerfile" >> "${filename}"
      \rm -f "${DOCKERFILE_LOCATION}/${comp}/${DOCKERFILE_GENERATED_NAME}/${version}/${DOCKER_ARCH}/Dockerfile"
    done

    __record_ubuntu_header "${filename}"
    __record_ubuntu_body "${filename}"
    __record_ubuntu_environment "${filename}"
    __record_addon_variables "${filename}"

    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
    typeset subimage_id=0

    for comp in ${components}
    do
      typeset comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
      subimage_id="$( printf "%s\n" ${DOCKER_SUBIMAGE_MAPPING} | \grep "^${comp}" | \cut -f 2 -d ':' )"

      typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"
      typeset orig_install_dir=
      typeset home=

      case "${upcomp}" in
      'MAVEN'  )  eval "home=\${M2_HOME}"; orig_install_dir="$( \dirname "${home}" )/apache-maven-${MAVEN_VERSION}";;
      'ANT'    )  eval "home=\${${upcomp}_HOME}"; orig_install_dir="$( \dirname "${home}" )/apache-ant-${ANT_VERSION}";;
      'JAVA'   )  eval "home=\${${upcomp}_HOME}"; orig_install_dir="$( \dirname "${home}" )/oracle-jdk-${JAVA_VERSION}";;
      esac
 
      __record_ubuntu_copyfrom "${filename}" "${subimage_id}" "${orig_install_dir}/" "${orig_install_dir}/"
      __record_ubuntu_copyfrom "${filename}" "${subimage_id}" "${__ENTRYPOINT_DIR}/" "${__ENTRYPOINT_DIR}/"
      __record_ubuntu_linkage "${filename}" "${orig_install_dir}" "${upcomp}"
    done
    __record_ubuntu_copyfrom "${filename}" "${subimage_id}" '/usr/local/bin/synopsys_setup.sh' '/usr/local/bin/'
  fi

  [ "${DOCKER_COMPONENTS}" -ge 1 ] && __record_ubuntu_footer "${filename}"

  return "${RC}"
}

write_dockerfile_ubuntu()
{
  typeset RC=0
  typeset version="$1"

  typeset OUTPUT_DIR="${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}__${DOCKER_CONTAINER_VERSION}/${version}/${DOCKER_ARCH}"
 
  \mkdir -p "${OUTPUT_DIR}"

  DOCKERFILE="${OUTPUT_DIR}/Dockerfile"
  [ "${BUILD_TYPE}" -eq 1 ] && \rm -f "${DOCKERFILE}"

  prepare_ubuntu_docker_contents "${DOCKERFILE}"
  RC=$?

  unset prepare_ubuntu_docker_contents
  unset __SOFTWARE

  return "${RC}"
}
