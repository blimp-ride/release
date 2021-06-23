#!/usr/bin/env bash

#=import semver

_CMD_GREP='/bin/grep'
if [ 'Darwin' = "$(uname)" ]; then
  type ggrep >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    _CMD_GREP="$(which ggrep)"
  else
    error "Must install GNU grep with 'brew install grep'"
    exit 1
  fi
fi

usage() {
  echo 'Usage:' >&2
  echo "  release [--version=VERSION_OVERRIDE] 'notes about the release'" >&2
  echo "  release --version VERSION_OVERRIDE 'notes about the release'" >&2
}

git-get-latest-version() {
  git --no-pager tag --sort=v:refname | tail -n1
}

bump-patch() {
  local sv="${1}"
  [ -z "${sv}" ] && return 1
  local pv="${sv##*.}"
  jnv="${sv%.*}"
  [ "${pv}" = "${sv}" ] && return 1
  [ "${jnv}" = "${sv}" ] && return 1
  declare -i ipv=${pv}
  ipv=$(( $ipv + 1 ))
  echo "${jnv}.${ipv}"
}

validate-semver() {
  if [ -z "${1}" ]; then
    echo "Version cannot be empty!" >&2
    return 255
  fi

  local sv="${1}"
  gv="$(echo "${sv}" | "${_CMD_GREP}" -P '^[0-9]+\.[0-9]+\.[0-9]+$')"
  if ! [ "${gv}" = "${sv}" ]; then
    echo "Version [${sv}] is not a semantic version!" >&2
    return 255
  fi
  return 0
  # TODO: no leading zeroes in a part unless it's exactly one zero
}

declare -a release_files=()
read-release-files() {
  if [ -f 'package.sh' ]
    release_files+=('package.sh')
  fi
  if [ -f 'release-files' ]; then
    while read line; do
      release_files+=("${line}")
    done < <(cat 'release-files')
  fi
  [ ${#release_files[@]} -gt 0 ]
}

git-stuff() {
  [ -n "${release_notes}" ] && [ -n "${version}"  ] && \
    read-release-files && \
    git tag -a -m "${release_notes}" "${version}" && \
    git push --tag && \
    gh release create --notes "${release_notes}" "${version}" "${release_files[@]}"
}

release() {
  # Options
  if [ "${1}" = '--version' ]; then
    if [ $# -ne 3 ]; then
      usage
      exit 1
    fi
    version="${2}"
    validate-semver "${version}" || exit 1
    shift 2
  elif [ "${1:0:10}" == '--version=' ]; then
    version="${1:10}"
    validate-semver "${version}" || exit 1
  else
    git_version="$(git-get-latest-version)"
    version="$(bump-patch "${git_version}")"
    if [ $? -ne 0 ] || [ -z "${version}" ]; then
      echo "Could not bump patch from git version [${git_version}]" >&2
      exit 1
    fi
  fi
  release_notes="${1}"
  if [ -z "${release_notes}" ]; then
    echo "Release notes cannot be empty!" >&2
    usage
    exit 1
  fi

  # Main
  git-stuff
}
