FROM golang:1.10.3-alpine AS build-stage

ADD . /go/src/github.com/sythe21/go-build-template
WORKDIR /go/src/github.com/sythe21/go-build-template
RUN apk update && apk add make git
RUN make build

# Final Stage
FROM alpine:3.7

ARG GIT_COMMIT
ARG VERSION
ARG BUILD_DATE
LABEL REPO="https://github.com/sythe21/go-build-template"
LABEL GIT_COMMIT=$GIT_COMMIT
LABEL VERSION=$VERSION
LABEL BUILD_DATE=$BUILD_DATE

WORKDIR /

COPY --from=build-stage /go/bin/go-build-template /go-build-template
ENTRYPOINT ["/go-build-template"]
