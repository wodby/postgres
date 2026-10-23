# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := postgres
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_14.24-alpine := sha256:50fce0c9c54c43d8b02ce16cb9daff75eb94c09c4ee3d41c157852ebd9700c80
BASE_IMAGE_DIGEST_15.19-alpine := sha256:a8e042598834300dfaa17a54f695b87b7f25d3490433bbbe2ef3bffbb9747f24
BASE_IMAGE_DIGEST_16.15-alpine := sha256:f4610795587492cd4fb887c2dc3de301b813278bb6f616992061141b5f15ac36
BASE_IMAGE_DIGEST_17.11-alpine := sha256:eee6c6e1b0894fa4fe0075eb054af9fd1cf39a35321c2d4110626cfe506411fb
BASE_IMAGE_DIGEST_18.6-alpine := sha256:898c60cb390d1085bc97bdd6a1ae968757421df394b071848b52b1c09c89d6a5

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
