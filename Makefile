include Makefile.org

INFO  ?= echo [INFO]
OK    ?= echo [OK]
DOCKER ?= docker
TARGETARCH ?= amd64
TARGETOS ?= linux
REGISTRY_NAMESPACE ?= dex
REGISTRY_IMAGE ?= dex
REGISTRY_IMAGE_TAG_SHORT?= v2.43.0_ubi9

.PHONY: docker-build
docker-build:
	@$(INFO) $(DOCKER) build
	echo $(DOCKER) buildx build -f Dockerfile --build-arg TARGETARCH=${TARGETARCH} --build-arg TARGETOS=${TARGETOS} -t us.icr.io/${REGISTRY_NAMESPACE}/${REGISTRY_IMAGE}:${REGISTRY_IMAGE_TAG_SHORT} .
	$(DOCKER) buildx build -f Dockerfile --build-arg TARGETARCH=${TARGETARCH} --build-arg TARGETOS=${TARGETOS} -t us.icr.io/${REGISTRY_NAMESPACE}/${REGISTRY_IMAGE}:${REGISTRY_IMAGE_TAG_SHORT} .
	@$(OK) $(DOCKER) build