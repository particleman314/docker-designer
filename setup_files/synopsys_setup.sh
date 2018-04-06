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
## @Software Package : Synopsys Tool Setup
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.76
#
###############################################################################

###############################################################################
# Determine if debugging needs to be turned on (see how to pass environment
#   variable via docker)
###############################################################################
if [ -n "${ENABLE_DETAILS}" ] && [ "${ENABLE_DETAILS}" -eq 1 ]
then
  set -x 
else
  ENABLE_DETAILS=0
  export ENABLE_DETAILS
fi

record_environment()
{
  #############################################################################
  # Repord environment settings within the container
  #############################################################################
  set | \sort >> '/tmp/docker_env_synopsys.log'
}

###############################################################################
# MAIN
###############################################################################
record_environment

if [ -z "${__BYPASS__}" ] || [ "${__BYPASS__}" -ne 1 ]
then
  if [ -d "${__ENTRYPOINT_DIR}" ]
  then
    pushd "${__ENTRYPOINT_DIR}" > /dev/null 2>&1

    __setupfiles=
    if [ -f "${__ENTRYPOINT_DIR}/dependency.dat" ]
    then
      __line=
      while read -r __line
      do
        __prog="$( printf "%s\n" "${__line}" | \cut -f 1 -d ':' )"
        __setupfiles+=" synopsys_setup_${prog}.sh"
      done < 'dependency.dat'
    else
      __setupfiles="$( \find . -type f -name "synopsys_setup*.sh" )"
    fi

    for __sf in ${__setupfiles}
    do
      __sftype="$( printf "%s\n" "$( \basename "${__sf}" )" | \sed -e 's#synopsys_setup_\(\w*\).sh#\1#' )"
      [ -f ".no_install_${__sftype}.mrk" ] && continue
    
      . "${__sf}"
    done

    popd > /dev/null 2>&1
  fi
fi

exec "$@"