BASEIMAGE ?= "alpine:3.14"
REGISTRY ?= "ghcr.io/iceber/clusterpedia"

GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
RELEASE_ARCHS ?= amd64 arm64

# Git information, used to set clusterpedia version
GIT_VERSION ?= $(shell git describe --tags --dirty)
GIT_COMMIT_HASH ?= $(shell git rev-parse HEAD)
GIT_TREESTATE = "clean"
GIT_DIFF = $(shell git diff --quiet >/dev/null 2>&1; if [ $$? -eq 1 ]; then echo "1"; fi)
ifeq ($(GIT_DIFF), 1)
    GIT_TREESTATE = "dirty"
endif
BUILDDATE = $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

LDFLAGS := "-X github.com/clusterpedia-io/clusterpedia/pkg/version.gitVersion=$(GIT_VERSION) \
				-X github.com/clusterpedia-io/clusterpedia/pkg/version.gitCommit=$(GIT_COMMIT_HASH) \
				-X github.com/clusterpedia-io/clusterpedia/pkg/version.gitTreeState=$(GIT_TREESTATE) \
				-X github.com/clusterpedia-io/clusterpedia/pkg/version.buildDate=$(BUILDDATE)"

VERSION ?= "latest"
ifeq ($(VERSION), "")
	LATEST_TAG=$(shell git describe --tags)
	ifeq ($(LATEST_TAG),$(shell git describe --abbrev=0 --tags))
		VERSION=$(LATEST_TAG)
	endif
endif

all: apiserver clustersynchro-manager

gen-clusterconfigs:
	./hack/gen-clusterconfigs.sh

clean-clusterconfigs:
	./hack/clean-clusterconfigs.sh

apiserver:
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
			   -ldflags $(LDFLAGS) \
			   -o bin/apiserver \
			   cmd/apiserver/main.go

clustersynchro-manager:
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
			   -ldflags $(LDFLAGS) \
			   -o  bin/clustersynchro-manager \
			   cmd/clustersynchro-manager/main.go

images: image-apiserver image-clustersynchro-manager

image-apiserver:
	GOOS="linux" $(MAKE) apiserver
	docker buildx build \
		-t ${REGISTRY}/apiserver-$(GOARCH):$(VERSION) \
		--platform=linux/$(GOARCH) \
		--build-arg BASEIMAGE=$(BASEIMAGE) \
		--build-arg BINNAME=apiserver .
	    
image-clustersynchro-manager: 
	GOOS="linux" $(MAKE) clustersynchro-manager
	docker buildx build \
		-t $(REGISTRY)/clustersynchro-manager-$(GOARCH):$(VERSION) \
		--platform=linux/$(GOARCH) \
	    --build-arg BASEIMAGE=$(BASEIMAGE) \
		--build-arg BINNAME=clustersynchro-manager .

.PHONY: crds
crds:
	./hack/update-crds.sh

.PHONY: codegen
codegen:
	./hack/update-codegen.sh

.PHONY: vendor
vendor:
	go mod tidy
	go mod vendor

.PHONY: clean
clean:
	rm -rf bin

.PHONY: push-images
push-images: push-apiserver-image push-clustersynchro-manager-image

push-apiserver-image:
	set -e; \
	images=""; \
	for arch in $(RELEASE_ARCHS); do \
		GOARCH=$$arch $(MAKE) image-apiserver; \
		image=$(REGISTRY)/apiserver-$$arch:$(VERSION); \
		docker push $$image; \
	    images="$$images $$image"; \
		if [ $(VERSION) != latest ]; then \
		    latest_image=$(REGISTRY)/apiserver-$$arch:latest; \
			docker tag $$image $$latest_image \
			docker push $$latest_image; \
		fi; \
	done; \
	docker manifest create $(REGISTRY)/apiserver:$(VERSION) --amend $$images; \
	docker manifest push $(REGISTRY)/apiserver:$(VERSION); \
	if [ $(VERSION) != latest ]; then \
		docker manifest create $(REGISTRY)/apiserver:latest --amend $$images; \
		docker manifest push $(REGISTRY)/apiserver:latest; \
	fi;

push-clustersynchro-manager-image:
	set -e; \
	images=""; \
	for arch in $(RELEASE_ARCHS); do \
		GOOS="linux" GOARCH=$$arch $(MAKE) image-clustersynchro-manager; \
		image=$(REGISTRY)/clustersynchro-manager-$$arch:$(VERSION); \
		docker push $$image; \
	    images="$$images $$image"; \
	done; \
	docker manifest create $(REGISTRY)/clustersynchro-manager:$(VERSION) --amend $$images; \
	docker manifest push $(REGISTRY)/clustersynchro-manager:$(VERSION) 
