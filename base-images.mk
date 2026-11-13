# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.24-alpine := sha256:928ce526d67711997cc5c6949b55382d4e7cb559d981d5899df132e4936ec03e
BASE_IMAGE_DIGEST_15.19-alpine := sha256:eab009ce9447a891d9482702d370bbf132c18563bb87cfdcc2b815c6d3b0372f
BASE_IMAGE_DIGEST_16.15-alpine := sha256:aa6cb33cf4c19c765cefcf48d96176258800870a9a1e930ad126200f9d825139
BASE_IMAGE_DIGEST_17.11-alpine := sha256:e5d2edd28b1f8d40a0a6c0c9cdc545b19b56a0d5d88f94bc11a97d970d4700d0
BASE_IMAGE_DIGEST_18.7-alpine := sha256:75dcac3dfb1cd01ca3536910bbc84128759362f8b118bf8c55b38a94f68f3b73

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
