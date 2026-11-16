# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.25-alpine := sha256:e7d9e6aac7fe3232f7661da103aebc0ce38b04105b46af5e9edd5ef6bc343f20
BASE_IMAGE_DIGEST_15.20-alpine := sha256:23799e521dee9265a8b388ecf3bc0f1eaa34b95be67f5a76af4f8f6adb44c720
BASE_IMAGE_DIGEST_16.16-alpine := sha256:81e77a4833487b8132fe4b00bedd39dc3f74b8641e387f19312a48f7de218c2e
BASE_IMAGE_DIGEST_17.12-alpine := sha256:a77aa70e641402a21411b92b721c58d10f23b50ae5fdd2333efd22d166e1e5f7
BASE_IMAGE_DIGEST_18.7-alpine := sha256:b6972e1115a4ff8eba5d7f7d19184926d1e16d7d1136ae1e1a7ebf286da0f015

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
