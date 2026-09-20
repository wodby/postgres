#!/usr/bin/env bash

# Version aliases identify published releases; only primary tags publish images.
if [[ "${GITHUB_REF:-}" =~ ^refs/tags/.+-r[0-9]+$ ]]; then
    exit 0
fi

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
    image_revision="${GITHUB_REF##*/}"
    tags=("${minor_tag}-${image_revision}")
    if [[ "${image_revision}" =~ ^r[1-9][0-9]*$ ]]; then
      # PostgreSQL's two-part version is complete. Its r0-based alias is
      # published after all builds; reserve the primary counter for the major.
      tags=("${major_tag}-${image_revision}")
    elif [[ -n "${LATEST_MAJOR}" ]]; then
      tags+=("${major_tag}-${image_revision}")
    fi
  elif [[ -n "${LATEST_ALIAS}" ]]; then
    tags+=("${LATEST_ALIAS}")
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create TAG="${major_tag}" IMAGETOOLS_TAG="${tag}"
  done
fi
