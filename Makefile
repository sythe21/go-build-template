
BIN := go-build-template
REGISTRY ?= index.docker.io/rholcombe
PKG := github.com/sythe21/$(BIN)

VERSION := $(shell git describe --tags --always --dirty)
GIT_COMMIT=$(shell git rev-parse HEAD)
GIT_DIRTY=$(shell test -n "`git status --porcelain`" && echo "+CHANGES" || true)
IMAGE := $(REGISTRY)/$(BIN)
MAJOR_VERSION := $(shell git describe --abbrev=0 2> /dev/null || echo '0.0.0' | build/increment_version.sh -M)
MINOR_VERSION := $(shell git describe --abbrev=0 2> /dev/null || echo '0.0.0' | build/increment_version.sh -m)
PATCH_VERSION := $(shell git describe --abbrev=0 2> /dev/null || echo '0.0.0' | build/increment_version.sh -p)

default: test

help:
	@echo 'Management commands'
	@echo
	@echo 'Usage:'
	@echo '    make init-build      Downloads build dependencies'
	@echo '    make init            Downloads and installs all dependencies'
	@echo '    make build           Compile the project.'
	@echo '    make get-deps        runs dep ensure, mostly used for ci.'
	@echo '    make build-alpine    Compile optimized for alpine linux.'
	@echo '    make package         Build final docker image with just the go binary inside'
	@echo '    make test            Run tests on a compiled project.'
	@echo '    make login           Log in to docker registry - requires $DOCKER_USER and $DOCKER_PASS'
	@echo '    make tag             Tag image created by package with latest, git commit and version'
	@echo '    make tag-release     In addition to tag, also tags a :release build'
	@echo '    make push            Push tagged images to registry'
	@echo '    make push-release    In addition to push, also pushes a :release tag'
	@echo '    make release-major   Releases a new major version to github using goreleaser (i.e 1.0.0 -> 2.0.0)'
	@echo '    make release-minor   Releases a new minor version to github using goreleaser (i.e 1.0.0 -> 1.1.0)'
	@echo '    make release-patch   Releases a new patch version to github using goreleaser (i.e 1.0.0 -> 1.0.1)'
	@echo '    make clean           Clean the directory tree.'
	@echo '    make fmt             Formats go code'
	@echo '    make vet             Checks for suspicous constructs.'
	@echo '    make lint            Checks for golang syntax.'
	@echo '    make check           Runs vet and lint'
	@echo

init-build:
	go get -u github.com/golang/dep/cmd/dep
	go get -u golang.org/x/lint/golint
	go get -u golang.org/x/tools/cmd/goimports
	dep status 2>&1 > /dev/null || dep init

init: init-build
	go get -d github.com/goreleaser/goreleaser
	cd ${GOPATH}/src/github.com/goreleaser/goreleaser && dep ensure -vendor-only && make setup build && mv goreleaser ${GOPATH}/bin
	dep status 2>&1 > /dev/null || dep init

dep:
	dep ensure

dependencies: dep ensure

build:
	@echo "building ${BIN} ${VERSION}"
	@echo "GOPATH=${GOPATH}"
	CGO_ENABLED=0 go build \
	  -installsuffix "static" \
	  -ldflags '-X ${PKG}/version.VERSION=${VERSION} -X ${PKG}/version.GITCOMMIT=${GIT_COMMIT}${GIT_DIRTY}' \
	  -o ${GOPATH}/bin/${BIN} \
	  cmd/go-build-template/main.go

build-%:
	@echo "building ${BIN} ${VERSION}"
	@echo "GOPATH=${GOPATH}"
	CGO_ENABLED=0 GOOS=$* go build \
	  -installsuffix "static" \
	  -ldflags '-X ${PKG}/version.VERSION=${VERSION} -X ${PKG}/version.GITCOMMIT=${GIT_COMMIT}${GIT_DIRTY}' \
	  -o ${GOPATH}/bin/${BIN} \
	  cmd/go-build-template/main.go

fmt: $(GO_SOURCES)
	gofmt -w $<
	goimports -w $<

check: vet lint

vet:
	go vet ./...

lint:
	golint ./...

package:
	@echo "building image ${BIN} ${VERSION} $(GIT_COMMIT)"
	docker build --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` --build-arg VERSION=${VERSION} --build-arg GIT_COMMIT=$(GIT_COMMIT) -t $(BIN):local .

login: guard-DOCKER_USER guard-DOCKER_PASS
	@echo "Logging in to dockerhub ${REGISTRY}"	
	docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} ${REGISTRY}

tag:
	@echo "Tagging: latest ${VERSION}"
	docker tag $(BIN):local $(IMAGE):${VERSION}
	docker tag $(BIN):local $(IMAGE):latest

tag-release:
	@echo "Tagging: release"
	docker tag $(BIN):local $(IMAGE):release

push: tag
	@echo "Pushing docker image to registry: latest ${VERSION} $(GIT_COMMIT)"
	docker push $(IMAGE):${VERSION}
	docker push $(IMAGE):latest

push-release: tag tag-release push
	@echo "Pushing docker image to registry: release"
	docker push $(IMAGE):release

release-major: guard-GITHUB_TOKEN
	@echo "Releasing $(MAJOR_VERSION)"
	git tag -a v$(MAJOR_VERSION) -m "Releasing $(MAJOR_VERSION)"
	git push origin v$(MAJOR_VERSION)
	goreleaser --rm-dist

release-minor: guard-GITHUB_TOKEN
	@echo "Releasing $(MINOR_VERSION)"
	git tag -a v$(MINOR_VERSION) -m "Releasing $(MINOR_VERSION)"
	git push origin v$(MINOR_VERSION)
	goreleaser --rm-dist

release-patch: guard-GITHUB_TOKEN
	@echo "Releasing $(PATCH_VERSION)"
	git tag -a v$(PATCH_VERSION) -m "Releasing $(PATCH_VERSION)"
	git push origin v$(PATCH_VERSION)
	goreleaser --rm-dist

clean:
	@test ! -e bin/${BIN} || rm bin/${BIN}

test:
	go test -v ./...

guard-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi

.PHONY: init build clean test help default
