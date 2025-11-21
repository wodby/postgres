#!/usr/bin/env bash

set -ex

if [[ "${GITHUB_REF}" == refs/heads/master || "${GITHUB_REF}" == refs/tags/* ]]; then      
  minor_ver="${POSTGRES_VER}"
  minor_tag="${minor_ver}"
  major_tag="${minor_ver%.*}"

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
  elif [[ -n "${LATEST}" ]]; then
    tags+=("latest")
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create IMAGETOOLS_TAG=${tag}
  done
fi