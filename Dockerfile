# util
# This is added for refenrence
FROM alpine:3 as ci-base
RUN apk add make docker-cli git jq wget
RUN  LATEST=$(wget -qO- "https://api.github.com/repos/docker/buildx/releases/latest" | jq -r .name) && \
     wget https://github.com/docker/buildx/releases/download/$LATEST/buildx-$LATEST.linux-amd64 && \
     chmod a+x buildx-$LATEST.linux-amd64 && \
     mkdir -p ~/.docker/cli-plugins && \
     mv buildx-$LATEST.linux-amd64 ~/.docker/cli-plugins/docker-buildx

# Application
FROM golang:1.16 as ultra-boost-base

WORKDIR /app
COPY go.mod go.sum ./

RUN go mod download

FROM ultra-boost-base as builder-ultra-boost

ARG GO_LDFLAGS

COPY --from=ultra-boost-base /go /go
COPY --from=ultra-boost-base /app /app

WORKDIR /app

COPY main.go main.go

RUN CGO_ENABLED=0 go build -ldflags "${GO_LDFLAGS}" -tags timetzdata -o /ultra-boost github.com/OGKevin/ultra-boost

FROM scratch as ultra-boost
LABEL org.opencontainers.image.source=https://github.com/OGKevin/ultra-boost

COPY --from=alpine:latest /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder-ultra-boost /ultra-boost /ultra-boost
ENTRYPOINT ["/ultra-boost"]

# test
FROM builder-ultra-boost AS unit-tests-builder
# Preferably, we can use a script here to add all the test files, but for sake of simplicity and demo this is enough.
COPY main_test.go .

FROM unit-tests-builder AS unit-tests
RUN --mount=type=cache,id=testspace,target=/tmp --mount=type=cache,target=/.cache go test -v -count 1 -p 4 github.com/OGKevin/ultra-boost
