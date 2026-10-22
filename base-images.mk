# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.24-alpine := sha256:e73790e2702b489f664605acbec5f5da6981bc7e432f0489e52a53c9d1e7467f
BASE_IMAGE_DIGEST_15.19-alpine := sha256:d2c2ced0372e855e4c257a9e9b5725f403847c01cfb64facbf2b21dbdadb2d74
BASE_IMAGE_DIGEST_16.15-alpine := sha256:deb28ee471183cb0c303113dac9b2433c51eeeeb678def7af9a9ec5820367815
BASE_IMAGE_DIGEST_17.11-alpine := sha256:1bcc18d81671b02906296aad470ec9778a6b71016ce953092024b680bad007b0
BASE_IMAGE_DIGEST_18.6-alpine := sha256:83148c0bc09eac4d598b70a61e1404d0212b76c95c504bfd6c81a4c59ec91792

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
