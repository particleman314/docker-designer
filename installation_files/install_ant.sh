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
## @Software Package : Installer (Apache-Ant)
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
__BAD_INSTALL_MARKER_FILE="${__ENTRYPOINT_DIR}/.no_install_ant.mrk"

build_ant_from_source()
{
  return 0
}

install_setup_scripts()
{
  if [ ! -f 'synopsys_setup_ant.sh' ]
  then
    printf "%s\n" '[ ERROR ] Cannot install necessary setup script for Apache-Ant!' >&2
    \touch "${__BAD_INSTALL_MARKER_FILE}"
    return 1
  fi

  \mv -f 'synopsys_setup_ant.sh' "${__ENTRYPOINT_DIR}"
  [ ! -f "${__ENTRYPOINT_DIR}/.dependency.dat" ] && [ -f 'dependency.dat' ] && \mv -f 'dependency.dat' "${__ENTRYPOINT_DIR}"
  [ ! -f '/usr/local/bin/synopsys_setup.sh' ] && [ -f 'synopsys_setup.sh' ] && \mv -f 'synopsys_setup.sh' '/usr/local/bin/'
  return 0
}

make_symlinks()
{
  typeset actual_content_dir="$1"

  if [ -z "${actual_content_dir}" ] || [ ! -d "${actual_content_dir}" ]
  then
    printf "%s\n" '[ ERROR ] Cannot make symlinks to non-existence directory!' >&2
    \touch "${__BAD_INSTALL_MARKER_FILE}"
    return 1
  fi

  pushd "$( \dirname "${ANT_HOME}" )" >/dev/null 2>&1

  \ln -s "${actual_content_dir}" "${ANT_HOME}"

  popd >/dev/null 2>&1
  return 0
}

run_install()
{
  [ -z "${ANT_HOME}" ] && return 1

  \mkdir -p "${__ENTRYPOINT_DIR}"

  pushd "${__TEMP_INSTALL_DIR}" >/dev/null 2>&1

  typeset binfile="$( verify_bin )"
  typeset RC=$?

  [ "${RC}" -ne 0 ] && return "${RC}"

  typeset bindir="$( unpack_tarball "${binfile}" )"
  [ "${RC}" -ne 0 ] && return "${RC}"

  typeset target_installation_dir="$( \dirname "${ANT_HOME}" )/apache-ant-${ANT_VERSION}"

  \mkdir -p "${target_installation_dir}"

  \mv -f "${bindir}"/* "${target_installation_dir}"
  \rm -rf "${bindir}"

  make_symlinks "${target_installation_dir}"
  [ "${RC}" -ne 0 ] && return "${RC}"

  install_setup_scripts
  popd >/dev/null 2>&1

  return 0
}

unpack_tarball()
{
  typeset binfile="$1"

  \tar -zxvf "${binfile}" >/dev/null 2>&1
  \rm -f "${binfile}"

  typeset bindir="$( \find . -type d -maxdepth 1 -name "apache-ant*" -exec \basename "{}" \; )"

  if [ -z "${bindir}" ]
  then
    printf "%s\n" '[ ERROR ] Bad installation.  No unpacked binary installation directory found!' >&2
    \touch "${__BAD_INSTALL_MARKER_FILE}"
    return 1
  fi

  printf "%s\n" "${bindir}"
  return 0
}

verify_bin()
{
  typeset binfile="$( \find . -type f -maxdepth 1 -name "apache-ant*.tar.gz" -exec \basename "{}" \; )"

  if [ -z "${binfile}" ]
  then
    printf "%s\n" '[ ERROR ] Bad installation.  No binary installation file found!' >&2
    \touch "${__BAD_INSTALL_MARKER_FILE}"
    return 1
  fi

  printf "%s\n" "${binfile}"
  return 0
}

run_install
