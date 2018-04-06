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
## @Software Package : Installer (Composite Builder Pattern)
## @Application      : Docker Release Engineering
## @Language         : Bourne Shell
## @Version          : 0.35
#
###############################################################################

if [ -n "${ENABLE_DETAILS}" ] && [ "${ENABLE_DETAILS}" -eq 1 ]
then
  set -x 
else
  ENABLE_DETAILS=0
  export ENABLE_DETAILS
fi

__TEMP_INSTALL_DIR="$( \dirname "$0" )"

install_setup_scripts()
{
  typeset pkgname="$1"
  if [ ! -f "synopsys_setup_${pkgname}.sh" ]
  then
    printf "%s\n" "[ ERROR ] Cannot install necessary setup script for package << ${pkgname} >>!" >&2
    \touch "${__ENTRYPOINT_DIR}/.no_install_${pkgname}.mrk"
    return 1
  fi

  \mv -f "synopsys_setup_${pkgname}.sh" "${__ENTRYPOINT_DIR}"
  [ ! -f "${__ENTRYPOINT_DIR}/.dependency.dat" ] && [ -f 'dependency.dat' ] && \mv -f 'dependency.dat' "${__ENTRYPOINT_DIR}"
  [ ! -f '/usr/local/bin/synopsys_setup.sh' ] && [ -f 'synopsys_setup.sh' ] && \mv -f 'synopsys_setup.sh' '/usr/local/bin/'
  return 0
}

make_symlinks()
{
  typeset pkgname="$1"
  typeset actual_content_dir="$2"
  typeset symlink_dir="$3"

  if [ -z "${actual_content_dir}" ] || [ ! -d "${actual_content_dir}" ] || [ -z "${symlink_dir}" ] || [ -L "${symlink_dir}" ]
  then
    printf "%s\n" "[ ERROR ] Cannot make symlink for << ${pkgname} >>!" >&2
    \touch "${__ENTRYPOINT_DIR}/.no_install_${pkgname}.mrk"
    return 1
  fi

  pushd "$( \dirname "${actual_content_dir}" )" >/dev/null 2>&1

  \ln -s "${actual_content_dir}" "${symlink_dir}"

  popd >/dev/null 2>&1
  return 0
}

run_install()
{
  typeset RC=0
  \mkdir -p "${__ENTRYPOINT_DIR}"

  pushd '/tmp' >/dev/null 2>&1

  [ ! -f '/usr/local/bin/synopsys_setup.sh' ] && [ -f 'synopsys_setup.sh' ] && \mv -f 'synopsys_setup.sh' '/usr/local/bin/'

  if [ -f 'installation_drop.pkg' ]
  then
    typeset line=
    while read -r line
    do
      typeset pkgname="$( printf "%s\n" "${line}" | \cut -f 1 -d ':' )"
      typeset pkg_dest="$( printf "%s\n" "${line}" | \cut -f 2 -d ':' )"
      typeset pkg_src="$( printf "%s\n" "${line}" | \cut -f 3 -d ':' )"

      \cp -f "synopsys_setup_${pkgname}.sh" "${__ENTRYPOINT_DIR}/"
      typeset parent_pkg_dest="$( \dirname "${pkg_dest}" )"
      \mv -f "${pkg_src}" "${parent_pkg_dest}/"
      
      case "${pkgname}" in
      'java'   ) make_symlinks "${pkgname}" "${parent_pkg_dest}/${pkg_src}" "${JAVA_HOME}";;
      'ant'    ) make_symlinks "${pkgname}" "${parent_pkg_dest}/${pkg_src}" "${ANT_HOME}";;
      'maven'  ) make_symlinks "${pkgname}" "${parent_pkg_dest}/${pkg_src}" "${M2_HOME}";;
      esac

      RC=$?
      [ "${RC}" -ne 0 ] && return "${RC}"

      install_setup_scripts "${pkgname}"
      RC=$?
      [ "${RC}" -ne 0 ] && return "${RC}"

    done < "./installation_drop.pkg"
  fi

  popd >/dev/null 2>&1

  return "${RC}"
}

run_install
