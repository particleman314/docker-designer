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

BUILD_TYPE=0
CURRENT_IMAGE_ID=0

UBUNTU_PACKAGES=
ENV_SETTINGS=

trap "cleanup; exit 1" SIGINT SIGTERM

__read_defaults()
{
  typeset deffile="${__DEFAULTS_FILE:-${__CURRENT_DIR}/defaults}"
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
  	  [ -n "${value}" ] && ENV_SETTINGS+=" ${envname}=${value}"
  	else
  	  ENV_SETTINGS+=" ${envname}"
  	fi
  done
  return 0
}

### UGLY Hack
add_environment_setting_default()
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
      [ -n "${value}" ] && ENV_UBUNTU+=" ${envname}=${value}"
    else
      ENV_UBUNTU+=" ${envname}"
    fi
  done
  return 0  
}

build_image()
{
  typeset RC=0

  # Call getopt to validate the provided input.
  if [ "$( \uname )" == 'Darwin' ]
  then
    options=$( getopt 'hdj:a:m:u:p:e:xyzr:v:n:' $* )
  else
    options=$( getopt -o 'hdj:a:m:u:p:e:r:v:n:' --long 'help,dryrun,dockerdir:,java:,ant:,maven:,ubuntu:packages:contvers:contname:env:multistage,composite' -- "$@" )
  fi
  [ $? -eq 0 ] || { 
    __record 'ERROR' 'Incorrect options provided'
    exit 1
  }

  DOCKER_COMPONENTS=0
  UBUNTU_MAPPED=0

  eval set -- "${options}"
  while true
  do
    case "$1" in
    -h|--help)
        usage;
        exit 255;
        ;;
    -d|--dryrun)
        DOCKER_DRYRUN=1;
        ;;
    -r|--dockerdir)
        shift
        DOCKERFILE_LOCATION="$1";
        ;;
    -j|--java)
        shift;
        if [ -f 'lib/java_handler.sh' ];
        then
          . 'lib/java_handler.sh';
          DOCKER_COMPONENTS=$(( DOCKER_COMPONENTS + 1 ));
          DOCKER_COMPONENT_NAMES+=' PROG:java';

          __record 'INFO' 'Adding Java for docker build...';
        else
          __record 'ERROR' 'Cannot find JAVA handler library!';
        fi;
        ;;
    -a|--ant)
        shift;
        if [ -f 'lib/ant_handler.sh' ];
        then
          . 'lib/ant_handler.sh';
          DOCKER_COMPONENTS=$(( DOCKER_COMPONENTS + 1 ));
          DOCKER_COMPONENT_NAMES+=' PROG:ant';

          __record 'INFO' 'Adding Apache-Ant for docker build...';
        else
          __record 'ERROR' 'Cannot find Apache-Ant handler library!';
        fi;
        ;;
    -m|--maven)
        shift;
        if [ -f 'lib/maven_handler.sh' ];
        then
          . 'lib/maven_handler.sh';
        
          DOCKER_COMPONENTS=$(( DOCKER_COMPONENTS + 1 ));
          DOCKER_COMPONENT_NAMES+=' PROG:maven';

          __record 'INFO' 'Adding Apache-Maven for docker build...';
        else
          __record 'ERROR' 'Cannot find Apache-Maven handler library!';
        fi;
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
    -n|--contname)
        shift;
        DOCKERFILE_GENERATED_NAME="$1";
        ;;
    -v|--contvers)
        shift;
        DOCKER_CONTAINER_VERSION="$1";
        ;;
    -e|--env)
        shift;
        ENV_SETTINGS+=" $1";
        ;;
    -p|--package)
        shift;
        UBUNTU_PACKAGES+=" $1";
        ;;
    -x|--single)
        [ "${DOCKER_COMPONENTS}" -le 1 ] && BUILD_TYPE=1;
        ;;
    -y|--composite)
        BUILD_TYPE=2;
        ;;
    -z|--multistage)
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

  [ "${UBUNTU_MAPPED}" -eq 0 ] && map_ubuntu && DOCKER_COMPONENT_NAMES+=' OS:ubuntu'
  add_environment_setting_default "UBUNTU_NAME=${UBUNTU_NAME}" "UBUNTU_VERSION=${UBUNTU_VERSION}"

  write_dockerfile
  RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  if [ -z "${DOCKER_DRYRUN}" ] || [ "${DOCKER_DRYRUN}" -eq 0 ]
  then
    \which docker >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
      pushd "$( \dirname "${DOCKERFILE}" )" >/dev/null 2>&1
      \docker build --tag ${DOCKERFILE_GENERATED_NAME}:${DOCKER_CONTAINER_VERSION} .
      popd >/dev/null 2>&1
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
        typeset upprogs="$( printf "%s\n" "${progs}" | \tr '[:lower:]' '[:upper:]' )"
        typeset version=
        eval "version=\${${upprogs}_VERSION}"
        DOCKER_CONTAINER_VERSION="${version}"
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

      DOCKERFILE_GENERATED_NAME+="_${marker}${pvers}"
    done

    if [ -n "${DOCKERFILE_GENERATED_NAME}" ]
    then
      DOCKERFILE_GENERATED_NAME="$( printf "%s\n" "${DOCKERFILE_GENERATED_NAME}" | \sed -e 's#\.##g' )"
      DOCKERFILE_GENERATED_NAME="syn${DOCKERFILE_GENERATED_NAME}"
    fi
  fi

  [ -z "${DOCKERFILE_GENERATED_NAME}" ] && DOCKERFILE_GENERATED_NAME='syn_ubuntu'
  return 0
}

manage_docker_image()
{
  typeset request_image="$1"

  \docker images --format "{{.Repository}}:{{.Tag}}" | \grep -q "${request_image}"
  typeset RC=$?

  if [ "${RC}" -ne 0 ]
  then
    __record 'WARN' "Requested base image << ${request_image} >> not found in local docker repository!"
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
  typeset depfile="${__CURRENT_DIR}/dependencies"

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

  typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
  typeset comp=
  typeset version=

  for comp in ${components}
  do
    comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
    . "${__CURRENT_DIR}/dockerfile_reqs/write_dockerfile_${comp}.sh"

    typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"
    eval "version=\${${upcomp}_VERSION}"
 
    write_dockerfile_${comp} "${version}"
  done

  typeset os_component="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep  'OS:' )"
  os_component="$( printf "%s\n" "${os_component}" | \cut -f 2 -d ':' )"

  . "${__CURRENT_DIR}/dockerfile_reqs/write_dockerfile_${os_component}.sh"
  typeset upcomp="$( printf "%s\n" "${os_component}" | \tr '[:lower:]' '[:upper:]' )"

  eval "version=\${${upcomp}_VERSION}"
  write_dockerfile_${os_component} "${version}"
  RC=$?

  return "${RC}"
}

usage()
{
  cat <<-EOH
Usage : $0 [options]

NOTE: Long options are NOT provided when running under MacOSX

Options :
  -h | --help           Show this help screen and exit.
  -d | --dryrun         Build docker file(s) but do NOT initiate docker engine build.


  -j | --java <>        Enable Java inclusion into docker image.  Input associated
                           with this option is the version of the application.
  -a | --ant <>         Enable Apache-Ant inclusion into docker image.  Input
                           associated with this option is the version of the
                           application.
  -m | --maven <>       Enable Apache-Maven inclusion into docker image.  Input
                           associated with this option is the version of the
                           application.
  -u | --ubuntu <>      Enable Ubuntu server basis for docker image.  Input
                           associated with this option is either version ID or
                           code name for Ubuntu


  -r | --dockerdir <>   Define toplevel of tree representing docker files
  -v | --contvers  <>   Container version to associate to docker build
  -n | --contname  <>   Container repository name for docker build
  
  -e | --env <>         Environment setting to include into docker build image.
  -p | --package <>     Ubuntu package to include into upgrade of basis docker
                            image.  This option can be used more than once or
                            multiple packages can be associated per calling
                            instance (in quotes)


  -x | --single         Allow for a single builds for any applications to be made
                            into separate docker files
  -y | --composite      Allow for a composite dockerfile for all applications to be
                            assembled.
  -z | --multistage     Allow for a multistage dockerfile for all applications to be
                            assembled.
EOH
  return 0
}

###############################################################################
# Absolute minimum default settings
###############################################################################
__CURRENT_DIR="$( \pwd -L )"
__CLEANUP_FILE="${__CURRENT_DIR}/.cleanup"

__read_defaults

add_environment_setting_default "__ENTRYPOINT_DIR=${__ENTRYPOINT_DIR}"
DOCKER_IMAGE_ORDER=

build_image "$@"
cleanup
