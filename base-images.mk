# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.24-alpine := sha256:b084304744d27cbc34513a1d2916129bd6a33383fa17b79b9a9030a950f14870
BASE_IMAGE_DIGEST_15.19-alpine := sha256:aae6554de426ae1990f1a939ff183a0299146cf7142a6f4c379c3357af9cc2d8
BASE_IMAGE_DIGEST_16.15-alpine := sha256:aa6cb33cf4c19c765cefcf48d96176258800870a9a1e930ad126200f9d825139
BASE_IMAGE_DIGEST_17.11-alpine := sha256:3540c0362c809df084ffac0ae69fe794515f9de92692f02178bcdce0ef0302ac
BASE_IMAGE_DIGEST_18.6-alpine := sha256:123b17998ccaf47e53b502e8c6a1e79afd8f579c6f3eec83c563da026f957395

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
