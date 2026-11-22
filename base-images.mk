# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.25-alpine := sha256:e7d9e6aac7fe3232f7661da103aebc0ce38b04105b46af5e9edd5ef6bc343f20
BASE_IMAGE_DIGEST_15.20-alpine := sha256:e18480a22d6e48f4d816a6696769b1ec09ac73a824c5649e49c7d8b684913f3d
BASE_IMAGE_DIGEST_16.16-alpine := sha256:f2f98726820d0342055351c6e9d36e705f5bfffb3dd53ff556325114b08afb6d
BASE_IMAGE_DIGEST_17.12-alpine := sha256:f9cf3e1f0066f0eb0c48707d864f0ac5941e9ff454a072077d97a4d278d07d73
BASE_IMAGE_DIGEST_18.7-alpine := sha256:0115267ab5a509022df9319c77be365cef335adb71556c75f60f5360ee247e71

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
