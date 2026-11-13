# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.25-alpine := sha256:14078c4aa0db8e2e8492866138cafd796fc39afd5ecb5b1c6f26a912b07529f5
BASE_IMAGE_DIGEST_15.20-alpine := sha256:5cb339462bde5e6b617acedf6c2a3008f3aadc44a3c0507dd22226ee1279aee8
BASE_IMAGE_DIGEST_16.16-alpine := sha256:0adbf25a9e96d38823bb813f3ac0ed41fadb665c88f1df7fe6dbfb060cbdc106
BASE_IMAGE_DIGEST_17.12-alpine := sha256:34261f594522cf41dfcb76aefd42b9d201098b0e6b23c9c68733f169e4218b6f
BASE_IMAGE_DIGEST_18.7-alpine := sha256:75dcac3dfb1cd01ca3536910bbc84128759362f8b118bf8c55b38a94f68f3b73

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
