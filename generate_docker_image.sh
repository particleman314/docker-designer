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
## @Version          : 0.90
#
###############################################################################

if [ -n "${ENABLE_DETAILS}" ] && [ "${ENABLE_DETAILS}" -eq 1 ]
then
  set -x 
else
  ENABLE_DETAILS=0
  export ENABLE_DETAILS
fi

GETOPT_COMPATIBLE=1
BUILD_TYPE=0
ALLOW_COMPOSITE_BUILDER_PATTERN=0
CURRENT_IMAGE_ID=0
SKIP_CLEAN=0

UBUNTU_PACKAGES=
ENV_SETTINGS=

trap "cleanup; exit 1" SIGINT SIGTERM

__check_for_docker_builder_pattern_usage()
{
  BUILD_TYPE=2
  __record 'WARN' "Current version of docker << ${DOCKER_EXE_VERSION} >> does NOT support simplified multistage builds"
  __record 'WARN' "Reverting to older style of composite building..."
  if [ "${ALLOW_COMPOSITE_BUILDER_PATTERN}" -eq 1 ]
  then
    __record 'INFO' "Using 'builder pattern' for multistage request"
    BUILD_TYPE=3
  fi
  return 0
}

__read_defaults()
{
  typeset deffile="${__DEFAULTS_FILE:-${__PROGRAM_DIR}/defaults}"
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
    options=$( getopt 'ac:de:hn:p:qr:su:v:xyz' $* )
  else
    options=$( getopt -o 'ac:de:hn:p:qr:su:v:xyz' --long 'allowbuilder,dryrun,env:,help,contname:,package:,ubuntupackage:,dockerdir:,skipclean,ubuntu:,contvers:,single,composite,multistage' -- "$@" )
  fi
  [ $? -eq 0 ] || { 
    __record 'ERROR' 'Incorrect options provided'
    exit 1
  }

  DOCKER_QUIET_FLAG=
  DOCKER_COMPONENTS=0
  UBUNTU_MAPPED=0

  typeset pusharg=

  eval set -- "${options}"
  while true
  do
    case "$1" in
    -a|--allowbuilder)
        ALLOW_COMPOSITE_BUILDER_PATTERN=1;
        BUILD_TYPE=3;
        ;;
    -c|--ubuntupackage)
        shift;
        UBUNTU_PACKAGES+=" $1";
        ;;
    -d|--dryrun)
        DOCKER_DRYRUN=1;
        ;;
    -e|--env)
        shift;
        ENV_SETTINGS+=" $1";
        ;;
    -h|--help)
        usage;
        exit 255;
        ;;
    -n|--contname)
        shift;
        DOCKERFILE_GENERATED_NAME="$1";
        ;;
    -p|--package)
        shift;
        typeset combo="$1"
        typeset pkgname="$( printf "%s\n" "${combo}" | \cut -f 1 -d ':' )";
        typeset reqvers="$( printf "%s\n" "${combo}" | \cut -f 2- -d ':' )";
        [ "${pkgname}" == "${reqvers}" ] && reqvers='default'

        if [ -f "${__PROGRAM_DIR}/lib/${pkgname}_handler.sh" ];
        then
          [ -z "${reqvers}" ] && pusharg='default' || pusharg="${reqvers}"
          . "${__PROGRAM_DIR}/lib/${pkgname}_handler.sh" "${pusharg}";

          DOCKER_COMPONENTS=$(( DOCKER_COMPONENTS + 1 ));
          DOCKER_COMPONENT_NAMES+=" PROG:${pkgname}";

          __record 'INFO' "Adding Package << ${pkgname} >> for docker build...";
        else
          __record 'ERROR' "Cannot find ${pkgname} handler library!";
        fi;
        ;;
    -q|--quiet)
        DOCKER_QUIET_FLAG='--quiet'
        ;;
    -r|--dockerdir)
        shift
        DOCKERFILE_LOCATION="$1";
        ;;
    -s|--skipclean)
        SKIP_CLEAN=1;
        ;;
    -u|--ubuntu)
        shift;
        [ -z "$1" ] && pusharg="${__DEFAULT_UBUNTU_VERSION}" || pusharg="$1"

        typeset result="$( \awk -v a="${pusharg}" 'BEGIN {print (a == a + 0)}' )";

        [ ${result} -eq 0 ] && UBUNTU_NAME="$1";
        [ ${result} -eq 1 ] && UBUNTU_VERSION="$1";
        map_ubuntu;
        DOCKER_COMPONENT_NAMES+=' OS:ubuntu';
        __record 'INFO' "Using Ubuntu for docker build ( ${UBUNTU_VERSION} -- ${UBUNTU_NAME} )..."
        ;;
    -v|--contvers)
        shift;
        DOCKER_CONTAINER_VERSION="$1";
        ;;
    -x|--single)
        [ "${DOCKER_COMPONENTS}" -le 1 ] && BUILD_TYPE=1;
        ;;
    -y|--composite)
        [ "${ALLOW_COMPOSITE_BUILDER_PATTERN}" -eq 1 ] && BUILD_TYPE=3 || BUILD_TYPE=2;
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

  DOCKER_ARCH="$( \uname -m )"

  write_dockerfile
  RC=$?
  [ "${RC}" -ne 0 ] && return "${RC}"

  __record 'INFO' "Dockerfile generated at location --> $( \dirname "${DOCKERFILE}" )"

  run_docker
  RC=$?
  return "${RC}"
}

cleanup()
{
  [ "${SKIP_CLEAN}" -eq 1 ] && return 0

  if [ -f "${__CLEANUP_FILE}" ]
  then
    typeset line=
    while read -r line
    do
      [ -e "${line}" ] && \rm -rf "${line}"
    done < "${__CLEANUP_FILE}"
  fi

  [ -f "${__CLEANUP_FILE}" ] && \rm -f "${__CLEANUP_FILE}"

  [ -n "${DOCKER_EXE_VERSION}" ] && docker_cleanup

  return 0
}

docker_cleanup()
{
  typeset dangling_images="$( docker images -qf dangling=true --no-trunc )";
  [ -n "${dangling_images}" ] && \docker rmi --force ${dangling_images};
  dangling_images="$( docker images --format "{{.ID}}:{{.Tag}}" | \grep "none" | \cut -f 1 -d ':' )";
  [ -n "${dangling_images}" ] && \docker rmi --force ${dangling_images}
  \docker container prune --force >/dev/null 2>&1
}

generate_docker_tag()
{
  if [ -n "${DOCKERFILE_GENERATED_NAME}" ] && [ -n "${DOCKER_CONTAINER_VERSION}" ]
  then
    ### Order from commandline -- Need to reorder and handle dependencies
    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
    [ -n "${components}" ] && printf "%s" "${components}"
    return 0
  fi

  if [ -z "${DOCKERFILE_GENERATED_NAME}" ]
  then
    typeset progs="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep 'PROG' )"
    if [ -n "${progs}" ]
    then
      progs="$( printf "%s\n" "${progs}" | \cut -f 2 -d ':' | \awk '{printf "%s ",$0} END {print ""}' | \awk '{$1=$1;print}' )"
    fi

    [ "${BUILD_TYPE}" -ne 1 ] && progs="$( reorder_by_dependencies "${progs}" )"
    
    DOCKER_COMPONENTS="$( printf "%s\n" "${progs}" | \awk '{print NF}' )"
    if [ "${DOCKER_COMPONENTS}" -gt 1 ]
    then
      typeset osdesignation="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep 'OS' )"
      DOCKER_COMPONENT_NAMES="$( printf "%s\n" "${progs}" | \awk '{ for(i = 1; i <= NF; i++) { print "PROG:"$i } }' )"
      DOCKER_COMPONENT_NAMES+=" ${osdesignation}"
      reset_build_type_for_docker
    fi

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
      printf "${progs}"
      return 0
    fi

    typeset p=
    for p in ${progs}
    do
      typeset upp="$( printf "%s\n" "${p}" | \tr '[:lower:]' '[:upper:]' )"
      typeset pvers=
      eval "pvers=\${${upp}_VERSION}"
      if [ -z "${pvers}" ]
      then
        . "${__PROGRAM_DIR}/lib/${p}_handler.sh" 'default';
        eval "pvers=\${${upp}_VERSION}"
      fi
      typeset marker="${p:0:1}"

      DOCKERFILE_GENERATED_NAME+="_${marker}${pvers}"
    done

    if [ -n "${DOCKERFILE_GENERATED_NAME}" ]
    then
      DOCKERFILE_GENERATED_NAME="$( printf "%s\n" "${DOCKERFILE_GENERATED_NAME}" | \sed -e 's#\.##g' )"
      DOCKERFILE_GENERATED_NAME="syn${DOCKERFILE_GENERATED_NAME}"
    fi

    printf "%s\n" "${progs}"
  fi

  if [ -z "${DOCKERFILE_GENERATED_NAME}" ]
  then
    typeset components="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep -v 'OS:' )"
    [ -n "${components}" ] && printf "%s\n" "${components}"
    DOCKERFILE_GENERATED_NAME='syn_ubuntu'
  fi
  return 0
}

get_docker_version()
{
  typeset RC=0
  \which docker >/dev/null 2>&1
  RC=$?
  [ "${RC}" -eq 0 ] && DOCKER_EXE_VERSION="$( docker -v | \cut -f 3 -d ' ' | \cut -f 1-2 -d '.' )"
  return "${RC}"
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
    'hardy'   )  UBUNTU_VERSION='8.04';;
    'lucid'   )  UBUNTU_VERSION='10.04';;
    'precise' )  UBUNTU_VERSION='12.04';;
    'trusty'  )  UBUNTU_VERSION='14.04';;
    'xenial'  )  UBUNTU_VERSION='16.04';;
    'artsy'   )  UBUNTU_VERSION='17.10';;
    'bionic'  )  UBUNTU_VERSION='18.04';;
    esac
  else
    case "${UBUNTU_VERSION}" in
    '8.04'  )  UBUNTU_NAME='hardy';;
    '10.04' )  UBUNTU_NAME='lucid';;
    '12.04' )  UBUNTU_NAME='precise';;
    '14.04' )  UBUNTU_NAME='trusty';;
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
  typeset active_progs="$1"
  typeset depfile="${__PROGRAM_DIR}/setup_files/dependency.dat"

  [ -z "${active_progs}" ] && return 0

  if [ -f "${depfile}" ]
  then
    typeset counter=1
    typeset numwords="$( printf "%s\n" "${active_progs}" | \awk '{print NF}' )"
    while [ "${counter}" -le "${numwords}" ]
    do
      typeset active="$( printf "%s\n" "${active_progs}" | \cut -f ${counter} -d ' ' )"
      if [ "${active:0:1}" == '+' ]
      then
        counter=$(( counter + 1 ))
        continue
      fi

	  typeset match="$( \cat "${depfile}" | \grep "^${active}" )"
      typeset dependencies="$( printf "%s\n" "${match}" | \cut -f 2 -d ':' )"
      if [ -z "${dependencies}" ]
      then
        active_progs="$( printf "%s\n" "${active_progs}" | \awk -v n=${counter} '{ for(i = 1; i <= NF; i++) { if ( i == n )print "+"$i ; else print $i } }' | \tr '\n' ' ' )"
        counter=$(( counter + 1 ))
        continue
      fi

      typeset numdeps="$( printf "%s\n" "${dependencies}" | \awk '{print NF}' )"
      if [ "${counter}" -eq 1 ]
      then
        active_progs="${dependencies} ${active_progs}"
        typeset offset=$(( counter + numdeps ))
        active_progs="$( printf "%s\n" "${active_progs}" | \awk -v n=${offset} '{ for(i = 1; i <= NF; i++) { if ( i == n )print "+"$i ; else print $i } }' | \tr '\n' ' ' )"
      else
      	typeset justbefore=$(( counter - 1 ))
      	typeset beginline="$( printf "%s\n" "${active_progs}" | \cut -f 1-${justbefore} -d ' ' )"
      	typeset endline="$( printf "%s\n" "${active_progs}" | \cut -f ${counter}- -d ' ' )"
      	active_progs="${beginline} ${dependencies} ${endline}"
        typeset offset=$(( counter + numdeps ))
        active_progs="$( printf "%s\n" "${active_progs}" | \awk -v n=${offset} '{ for(i = 1; i <= NF; i++) { if ( i == n )print "+"$i ; else print $i } }' | \tr '\n' ' ' )"
        counter=1
      fi
      numwords="$( printf "%s\n" "${active_progs}" | \awk '{print NF}' )"
    done
  fi

  active_progs="$( printf "%s\n" "${active_progs}" | \tr ' ' '\n' | \awk '!unique[$0]++' )"
  active_progs="$( printf "%s\n" "${active_progs}" | \awk '{print substr($0,2)}' | \tr '\n' ' ' | \sed -e 's/ *$//g' )"
  printf "%s\n" "${active_progs}"
  return 0
}

reset_build_type_for_docker()
{
  typeset RC=0
  [ -z "${DOCKER_EXE_VERSION}" ] && get_docker_version
  
  if [ -n "${DOCKER_EXE_VERSION}" ]
  then
    typeset DOCKER_EXE_MAJOR_VERSION="$( printf "%s\n" "${DOCKER_EXE_VERSION}" | \cut -f 1 -d '.' )"
    typeset DOCKER_EXE_MINOR_VERSION="$( printf "%s\n" "${DOCKER_EXE_VERSION}" | \cut -f 2 -d '.' )"
    DOCKER_EXE_MINOR_VERSION="$( \awk -v a="${DOCKER_EXE_MINOR_VERSION}" 'BEGIN {print (a == a + 0)}' )"

    if [ "${DOCKER_EXE_MAJOR_VERSION}" -le 17 ]
    then
      if [ "${DOCKER_EXE_MINOR_VERSION}" -lt 5 ]
      then
        [ "${BUILD_TYPE}" -eq 4 ] && __check_for_docker_builder_pattern_usage
      fi
    fi
  fi

  case "${BUILD_TYPE}" in
  1)  BUILD_TYPE_NAME='SINGLE';;
  2)  BUILD_TYPE_NAME='COMPOSITE (MONOLITHIC)';;
  3)  BUILD_TYPE_NAME='COMPOSITE (STAGED BUILDS)';;
  4)  BUILD_TYPE_NAME='MULTI_STAGE (OPTIMIZED)';;
  *)  BUILD_TYPE_NAME='UNKNOWN';;
  esac

  return "${RC}"
}

run_docker()
{
  typeset RC=0

  if [ -z "${DOCKER_DRYRUN}" ] || [ "${DOCKER_DRYRUN}" -eq 0 ]
  then
    get_docker_version
    if [ -n "${DOCKER_EXE_VERSION}" ]
    then
      __record 'INFO' "Using Docker version --> ${DOCKER_EXE_VERSION}"
      docker_cleanup

      reset_build_type_for_docker
      RC=$?
      [ "${RC}" -ne 0 ] && return "${RC}"

      __record 'INFO' "Requested/Inferred Build Type : ${BUILD_TYPE_NAME}"

      if [ "${BUILD_TYPE}" -eq 2 ] || [ "${BUILD_TYPE}" -eq 3 ]
      then
        if [ "${ALLOW_COMPOSITE_BUILDER_PATTERN}" -eq 1 ]
        then
          record_cleanup "$( \ls -1 ${__PROGRAM_DIR}/ubuntu/${DOCKERFILE_GENERATED_NAME}__${DOCKER_CONTAINER_VERSION}/${UBUNTU_VERSION}/${DOCKER_ARCH}/components )"
          . "${__PROGRAM_DIR}/lib/composite_builder.sh"
        fi
        . "${__PROGRAM_DIR}/lib/run_docker_build.sh" "${DOCKERFILE}"
        RC=$?
      else
        . "${__PROGRAM_DIR}/lib/run_docker_build.sh" "${DOCKERFILE}"
        RC=$?
      fi
    fi
  fi

  return "${RC}"
}

write_dockerfile()
{
  typeset RC=0

  generate_docker_tag > "${__CURRENT_DIR}/.tempoutput"
  RC=$?
  if [ "${RC}" -ne 0 ]
  then
    __record 'ERROR' 'Unable to generate repository name for requested Docker container!'
    \rm -f "${__CURRENT_DIR}/.tempoutput"
    return "${RC}"
  fi

  [ "${BUILD_TYPE}" -eq 4 ] && \rm -rf "${DOCKERFILE_LOCATION}/ubuntu/${DOCKERFILE_GENERATED_NAME}/${UBUNTU_VERSION}"

  typeset ordered_components="$( \cat "${__CURRENT_DIR}/.tempoutput" )"
  \rm -f "${__CURRENT_DIR}/.tempoutput"

  typeset comp=
  typeset version=

  for comp in ${ordered_components}
  do
    comp="$( printf "%s\n" "${comp}" | \cut -f 2 -d ':' )"
    . "${__PROGRAM_DIR}/dockerfile_reqs/write_dockerfile_${comp}.sh"
    RC=$?

    [ "${RC}" -ne 0 ] && return "${RC}"

    typeset upcomp="$( printf "%s\n" "${comp}" | \tr '[:lower:]' '[:upper:]' )"
    if [ "${BUILD_TYPE}" -ne 2 ]
    then
      eval "version=\${${upcomp}_VERSION}"
    else
      version="${UBUNTU_VERSION}"
    fi

    write_dockerfile_${comp} "${version}"
    RC=$?
    [ "${RC}" -ne 0 ] && return "${RC}"
  done

  if [ "${BUILD_TYPE}" -gt 1 ]
  then
    typeset os_component="$( printf "%s\n" ${DOCKER_COMPONENT_NAMES} | \grep  'OS:' )"
    os_component="$( printf "%s\n" "${os_component}" | \cut -f 2 -d ':' )"

    . "${__PROGRAM_DIR}/dockerfile_reqs/write_dockerfile_${os_component}.sh"
    typeset upcomp="$( printf "%s\n" "${os_component}" | \tr '[:lower:]' '[:upper:]' )"

    eval "version=\${${upcomp}_VERSION}"
    write_dockerfile_${os_component} "${version}"
    RC=$?
  fi

  return "${RC}"
}

usage()
{
  cat <<-EOH
Usage : $0 [options]

NOTE: Long options are NOT provided when running under MacOSX

Options :
  -a | --allowbuilder       Allow for multistage pseudo processing
  -c | --ubuntupackage <>   Ubuntu package to include into upgrade of basis docker
                               image.  This option can be used more than once or
                               multiple packages can be associated per calling
                               instance (in quotes)
  -d | --dryrun             Build docker file(s) but do NOT initiate docker engine build(s).
  -e | --env <>             Environment setting to include into docker build image.
  -h | --help               Show this help screen and exit.
  -n | --contname <>        Container repository name for docker build.
  -p | --package <>         Enable package inclusion into docker image.  Input associated
                               with this option is the version of the application.
                               This option can be used more than once.
  -q | --quiet              Request docker building to be "less" chatty.
  -r | --dockerdir <>       Define toplevel of tree representing docker files
  -s | --skipclean          Skip cleaning up once script ends.
  -u | --ubuntu <>          Enable Ubuntu server basis for docker image.  Input
                               associated with this option is either version ID or
                               code name for Ubuntu OS requested.
                               Default version of Ubuntu is '${__DEFAULT_UBUNTU_VERSION}'
  -v | --contvers <>        Container version to associate to docker build.
                               Default version is '${__DEFAULT_CONTAINER_VERSION}'
  -x | --single             Allow for a single builds for any applications to be made
                               with separate docker files
  -y | --composite          Allow for a composite dockerfile for all applications to be
                               assembled.  Use (-a|--allowbuilder}) to mimic multistage
                               building with older docker version.
  -z | --multistage         Allow for true multistage dockerfile for all applications to be
                               assembled.  Works with docker version 17.05 or higher only.
                               Composite building will be reselected if docker version is not
                               sufficient.
EOH
  return 0
}

###############################################################################
# Absolute minimum default settings
###############################################################################
__CURRENT_DIR="$( \pwd -L )"

__PROGRAM_DIR="$( \dirname "$0" )"
pushd "${__PROGRAM_DIR}" >/dev/null 2>&1
__PROGRAM_DIR="$( \pwd -L )"
popd >/dev/null 2>&1

__CLEANUP_FILE="${__CURRENT_DIR}/.cleanup"

__read_defaults

add_environment_setting_default "__ENTRYPOINT_DIR=${__ENTRYPOINT_DIR}"
#add_environment_setting_default "ENABLE_DETAILS=1" "__BYPASS__=1"

build_image "$@"
__RC=$?

cleanup

exit "${__RC}"
