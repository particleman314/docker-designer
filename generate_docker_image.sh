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
## @Software Package : Docker Image Generator
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.56
#
###############################################################################

if [ -n "${ENABLE_DETAILS}" ] && [ "${ENABLE_DETAILS}" -eq 1 ]
then
  set -x 
else
  ENABLE_DETAILS=0
  export ENABLE_DETAILS
fi

###############################################################################
# Absolute minimum default settings
###############################################################################
__CURRENT_DIR="$( \pwd -L )"
__CLEANUP_FILE="${__CURRENT_DIR}/.cleanup"
__ENTRYPOINT_DIR='/usr/local/bin/docker-entries.d'

trap "cleanup; exit 1" SIGINT SIGTERM

BUILD_TYPE=0

UBUNTU_PACKAGES=
ENV_LOOKUP=

__read_defaults()
{
  typeset deffile="${__CURRENT_DIR}/.defaults"
  [ ! -f "${deffile}" ] && return 0

  . "${deffile}"

  ### Read packages for ubuntu
  UBUNTU_PACKAGES+="$( \cat "${deffile}" | \grep "^#package:" | \cut -f 2 -d ':' | \sed -e "s/\n/ /g" )"
  return 0
}

__record()
{
  typeset msgtype="${1:-INFO}"
  msgtype="$( printf "%s\n" "${msgtype}" | \tr '[:lower:]' '[:upper:]' )"

  typeset message="$2"

  typeset use_stderr="${3:-0}"
  if [ "${use_stderr}" != '0' ]
  then
    use_stderr='>&2'
  else
    use_stderr=
  fi

  [ -z "${message}" ] && return 0

  case "${msgtype}" in
  'DEBUG'|'TRACE'  )  printf "%s\n" "[ DEBUG ] ${message}" ${use_stderr};;
  'WARN'|'WARNING' )  printf "%s\n" "[ WARN  ] ${message}" ${use_stderr};;
  'INFO'           )  printf "%s\n" "[ INFO  ] ${message}" ${use_stderr};;
  'ERROR'          )  printf "%s\n" "[ ERROR ] ${message}" ${use_stderr};;
  esac
  return 0
}

add_environment_setting()
{
  typeset envname=
  for envname in $@
  do
  	typeset first="$( printf "%s\n" "${envname}" | \cut -f 1 -d '=' )"
  	typeset second="$( printf "%s\n" "${envname}" | \cut -f 2 -d '=' )"

  	if [ "${first}" == "${second}" ]
  	then
  	  typeset value=
  	  eval "value=\${${envname}}"
  	  [ -n "${value}" ] && ENV_LOOKUP+=" ${envname}=${value}"
  	else
  	  ENV_LOOKUP+=" ${envname}"
  	fi
  done
  return 0
}

build_image()
{
  typeset RC=0

  # Call getopt to validate the provided input. 
  options=$( getopt -o 'dj:a:m:u:p:e:' --long 'dryrun,dockerdir:,java:,ant:,maven:,ubuntu:packages:contvers:contname:env:multistage,composite' -- "$@" )
  [ $? -eq 0 ] || { 
    __record 'ERROR' 'Incorrect options provided'
    exit 1
  }

  UBUNTU_MAPPED=0
  add_environment_setting ' __ENTRYPOINT_DIR'

  eval set -- "$options"
  while true
  do
    case "$1" in
    -d|--dryrun)
        DOCKER_DRYRUN=1;
        ;;
      --dockerdir)
        shift
        DOCKERFILE_LOCATION="$1";
        ;;
    -j|--java)
        shift; # The arg is next in position args
        JAVA_VERSION="$( printf "%s\n" "$1" | \cut -f 1 -d ':' )";
        JAVA_MAJOR_VERSION="$( printf "%s\n" "${JAVA_VERSION}" | \cut -f 2 -d '.' )";
        JAVA_HOME="$( printf "%s\n" "$1" | \cut -f 2 -d ':' )";
        [ "${JAVA_HOME}" == "${JAVA_VERSION}" ] && JAVA_HOME="${__DEFAULT_JAVA_HOME}";
        JDK_HOME="${JAVA_HOME}";
        DOCKER_COMPONENTS=$(( DOCKER_COMPONENTS + 1 ));
        DOCKER_COMPONENT_NAMES+=' PROG:java';

        add_environment_setting 'JAVA_VERSION' 'JAVA_MAJOR_VERSION' 'JAVA_HOME' 'JDK_HOME';

        __record 'INFO' 'Adding Java for docker build...'
        ;;
    -a|--ant)
        shift;
        ANT_VERSION="$( printf "%s\n" "$1" | \cut -f 1 -d ':' )";
        ANT_HOME="$( printf "%s\n" "$1" | \cut -f 2 -d ':' )";
        [ "${ANT_HOME}" == "${ANT_VERSION}" ] && ANT_HOME="${__DEFAULT_ANT_HOME}";
        DOCKER_COMPONENTS=$(( DOCKER_COMPONENTS + 1 ));
        DOCKER_COMPONENT_NAMES+=' PROG:ant';

        add_environment_setting 'ANT_VERSION' 'ANT_HOME';

        __record 'INFO' 'Adding Apache-Ant for docker build...'
        ;;
    -m|--maven)
        shift;
        MAVEN_VERSION="$( printf "%s\n" "$1" | \cut -f 1 -d ':' )";
        M2_HOME="$( printf "%s\n" "$1" | \cut -f 2 -d ':' )";
        [ "${M2_HOME}" == "${MAVEN_VERSION}" ] && M2_HOME="${__DEFAULT_MAVEN_HOME}";
        DOCKER_COMPONENTS=$(( DOCKER_COMPONENTS + 1 ));
        DOCKER_COMPONENT_NAMES+=' PROG:maven';

        add_environment_setting 'MAVEN_VERSION' 'M2_HOME';

        __record 'INFO' 'Adding Apache-Maven for docker build...'
        ;;
    -u|--ubuntu)
        shift;
        typeset result="$( \awk -v a="$1" 'BEGIN {print (a == a + 0)}' )";
        [ ${result} -eq 0 ] && UBUNTU_NAME="$1";
        [ ${result} -eq 1 ] && UBUNTU_VERSION="$1";
        map_ubuntu;
        DOCKER_COMPONENT_NAMES+=' OS:ubuntu';
        __record 'INFO' 'Using Ubuntu for docker build...'
        ;;
       --contname)
        shift;
        DOCKERFILE_GENERATED_NAME="$1";
        ;;
       --contvers)
        shift;
        DOCKER_CONTAINER_VERSION="$1";
        ;;
    -e|--env)
        shift;
        ENV_LOOKUP+=" $1";
        ;;
    -p|--package)
        shift;
        UBUNTU_PACKAGES+=" $1";
        ;;
       --single)
        BUILD_TYPE=1;
        ;;
       --composite)
        BUILD_TYPE=2;
        ;;
       --multistage)
		BUILD_TYPE=4;
		;;
    --)
        shift
        break
        ;;
    esac
    shift

    [ "${DOCKER_COMPONENTS}" -gt 1 ] && [ "${BUILD_TYPE}" -eq 0 ] && BUILD_TYPE=2
  done

  [ "${BUILD_TYPE}" -eq 0 ] && BUILD_TYPE=1
  [ -z "${DOCKERFILE_LOCATION}" ] && DOCKERFILE_LOCATION="${__DEFAULT_DOCKERFILE_LOCATION}"

  [ -z "${DOCKER_CONTAINER_VERSION}" ] && \
      DOCKER_CONTAINER_VERSION="${DEFAULT_CONTAINER_VERSION:-${__DEFAULT_CONTAINER_VERSION}}"

  [ "${UBUNTU_MAPPED}" -eq 0 ] && map_ubuntu
  add_environment_setting "UBUNTU_NAME=${UBUNTU_NAME}" "UBUNTU_VERSION=${UBUNTU_VERSION}"

  write_dockerfile

  if [ -z "${DOCKER_DRYRUN}" ] || [ "${DOCKER_DRYRUN}" -eq 0 ]
  then
    \which docker >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
      pushd "${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}"
      \docker build --tag ${DOCKERFILE_GENERATED_NAME}:${DOCKER_CONTAINER_VERSION} .
      popd
      RC=$?
    fi
  fi
  return "${RC}"
}

cleanup()
{
  if [ -f "${__CLEANUP_FILE}" ]
  then
    \cat "${__CLEANUP_FILE}"
    typeset line=
    while read -r line
    do
      [ -e "${line}" ] && \rm -rf "${line}"
    done < "${__CLEANUP_FILE}"
  fi

  \rm -f "${__CLEANUP_FILE}"
  return 0
}

generate_docker_tag()
{
  [ -n "${DOCKERFILE_GENERATED_NAME}" ] && [ -n "${DOCKER_CONTAINER_VERSION}" ] && return 0

  if [ -z "${DOCKERFILE_GENERATED_NAME}" ]
  then
    typeset progs="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep 'PROG' )"
    if [ -n "${progs}" ]
    then
      progs="$( printf "%s\n" "${progs}" | \cut -f 2 -d ':' | \sed -e "s/\n/ /g" | \awk '{$1=$1;print}' )"
    fi

    progs="$( reorder_by_dependencies "${progs}" )"
    if [ "${DOCKER_COMPONENTS}" -eq 1 ]
    then
      if [ -z "${progs}" ]
      then
        DOCKERFILE_GENERATED_NAME='syn_ubuntu'
      else
        DOCKERFILE_GENERATED_NAME="syn_${progs}"
      fi
      return 0
    fi

    typeset p=
    for p in ${progs}
    do
      typeset upp="$( printf "%s\n" "${p}" | \tr '[:lower:]' '[:upper:]' )"

      typeset pvers=
      eval "pvers=\${${upp}_VERSION}"
      typeset marker="${p:0:1}"

      DOCKERFILE_GENERATED_NAME="${marker}${pvers}"
    done

    DOCKERFILE_GENERATED_NAME="$( printf "%s\n" "${DOCKERFILE_GENERATED_NAME}" | \sed -e 's#\.##g' )"
  fi

  if [ -z "${DOCKER_CONTAINER_VERSION}" ]
  then
    if [ -f "${__CURRENT_DIR}/.defaults" ]
    then
      \cat "${__CURRENT_DIR}/.defaults" | \grep -v '__DEFAULT_CONTAINER_VERSION=' > "${__CURRENT_DIR}/.defaults.tmp"
      printf "%s\n" '1.0' >> "${__CURRENT_DIR}/.defaults.tmp"
      \mv -f "${__CURRENT_DIR}/.defaults.tmp" "${__CURRENT_DIR}/.defaults"
    fi
  fi
  return 0
}

make_dockerfile()
{
  write_dockerfile_header
  typeset RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
  typeset comp=

  ### Need to handle dependency capability
  for comp in ${components}
  do
    comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"

    typeset uppcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"

    [ "${BUILD_TYPE}" -eq 2 ] && eval "${uppcomp}_MULTISTAGE=1" || eval "${uppcomp}_MULTISTAGE=0"
    [ "${BUILD_TYPE}" -eq 4 ] && eval "${uppcomp}_COMPOSITE=1" || eval "${uppcomp}_COMPOSITE=1"

    . "${__CURRENT_DIR}/dockerfile_reqs/write_dockerfile_${comp}.sh"
    write_dockerfile_${comp}
  done

  write_dockerfile_body
  write_dockerfile_footer
  return 0
}

manage_docker_image()
{
  typeset request_image="$1"

  \docker images --format "{{.Repository}}:{{.Tag}}" | \grep -q "${request_image}"
  typeset RC=$?

  if [ "${RC}" -ne 0 ]
  then
    printf "%s\n" "[ ERROR ] Requested base image << ${request_image} >> not found in local docker repository!"
  fi

  return "${RC}"
}

map_ubuntu()
{
  UBUNTU_MAPPED=1
  if [ -z "${UBUNTU_VERSION}" ]
  then
    case "${UBUNTU_NAME}" in
    'trusty' )  UBUNTU_VERSION='14.04';;
    'xenial' )  UBUNTU_VERSION='16.04';;
    'artsy'  )  UBUNTU_VERSION='17.10';;
    'bionic' )  UBUNTU_VERSION='18.04';;
    esac
  else
    case "${UBUNTU_VERSION}" in
    '12.04' )  UBUNTU_NAME='trusty';;
    '16.04' )  UBUNTU_NAME='xenial';;
    '17.10' )  UBUNTU_NAME='artsy';;
    '18.04' )  UBUNTU_NAME='bionic';;
    esac
  fi

  if [ -z "${UBUNTU_VERSION}" ] || [ -z "${UBUNTU_NAME}" ]
  then
    UBUNTU_VERSION="${DEFAULT_UBUNTU_VERSION:-${__DEFAULT_UBUNTU_VERSION}}"

    if [ -z "${UBUNTU_VERSION}" ]
    then
      __record 'ERROR' 'Need to define UBUNTU_VERSION environment variable to continue!'
      exit 1
    fi
    map_ubuntu  # Recursive call...
  fi

  return 0
}

record_cleanup()
{
  typeset new_cleanup_file_or_dir="$1"
  [ -z "${new_cleanup_file_or_dir}" ] && return 0

  printf "%s\n" "${new_cleanup_file_or_dir}" >> "${__CLEANUP_FILE}"
}

reorder_by_dependencies()
{
  typeset known_progs="$1"
  typeset depfile="${__CURRENT_DIR}/.dependencies"

  if [ ! -f "${depfile}" ]
  then
    printf "%s\n" "${known_progs}"
    return 0
  fi

  return 0
}

write_dockerfile()
{
  typeset RC=0

  generate_docker_tag
  RC=$?
  if [ "${RC}" -ne 0 ]
  then
    __record 'ERROR' 'Unable to generate repository name for requested Docker container!'
    return "${RC}"
  fi

  [ -n "${DOCKERFILE_LOCATION}" ] && [ -n "${DOCKERFILE_GENERATED_NAME}" ] && \
     \mkdir -p "${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}"

  make_dockerfile
  return $?
}

write_dockerfile_footer()
{
  \cat <<-EOD >> ${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}/Dockerfile
##############################################################################
# Define the entrypoint now for the container
##############################################################################
ENTRYPOINT [ "synopsys_setup.sh" ]
EOD
  return 0
}

write_dockerfile_header()
{
  typeset RC=0
  printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -q 'ubuntu'

  \cat <<-EOD > ${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}/Dockerfile
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

EOD
  return 0
}

write_dockerfile_body()
{
  typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
  typeset comp=

  for comp in ${components}
  do
  	comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
    \cat "${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}/DockerSubcomponent_${comp}" >> "${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}/Dockerfile"
  done

  \cat <<-EOD >> ${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}/Dockerfile
ENV ${ENV_LOOKUP}

EOD

  \cat <<-EOD >> ${DOCKERFILE_LOCATION}/${DOCKERFILE_GENERATED_NAME}/Dockerfile
##############################################################################
# Install a binary version of requested software
##############################################################################
COPY components/* /tmp/

EOD
  return 0
}

__read_defaults
build_image "$@"
cleanup
