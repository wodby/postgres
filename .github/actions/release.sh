#!/usr/bin/env bash

set -ex

if [[ "${GITHUB_REF}" == refs/heads/master || "${GITHUB_REF}" == refs/tags/* ]]; then      
  minor_ver="${POSTGRES_VER}"
  major_ver="${minor_ver%.*}"
  minor_tag="${minor_ver}${TAG_SUFFIX}"
  major_tag="${major_ver}${TAG_SUFFIX}"

  tags=("${minor_tag}")
  if [[ -n "${LATEST_MAJOR}" ]]; then
     tags+=("${major_tag}")
  fi

  if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    stability_tag="${GITHUB_REF##*/}"
    tags=("${minor_tag}-${stability_tag}")
    if [[ -n "${LATEST_MAJOR}" ]]; then
      tags+=("${major_tag}-${stability_tag}")
    fi
  elif [[ -n "${LATEST_ALIAS}" ]]; then
    tags+=("${LATEST_ALIAS}")
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create TAG="${major_tag}" IMAGETOOLS_TAG="${tag}"
  done
fi
