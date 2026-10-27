# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.24-alpine := sha256:862ffc2556a2db763f0439c8323490000cd01975d2798a845e4a8dd3a905862f
BASE_IMAGE_DIGEST_15.19-alpine := sha256:54e0dd8e8cddcdbb9156c2486eed5a43eccb7214d7c6828097d41ce049fb3984
BASE_IMAGE_DIGEST_16.15-alpine := sha256:0cefaabd882e42bcb2a2f3dc56d3ce4770560ba62fd7f197f1a2e008fd5731ab
BASE_IMAGE_DIGEST_17.11-alpine := sha256:266d3c257594e195b309ae9d1805e54c788f1d7b375f56bf6c367aac6c917e7b
BASE_IMAGE_DIGEST_18.6-alpine := sha256:10a5c69a83035ab5239f5620d708520e8b28f5aa1f2b20143e6024532edadfb5

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
