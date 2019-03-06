#####
FROM golang:1.11.4-stretch as protoc_builder
ENV PROTOBUF_TAG='v3.6.1' \
    GOPATH=/go \
    PATH=$PATH:/go/bin/ \
    OUTDIR=/out
RUN mkdir -p /go/bin
COPY . $GOPATH/src/github.com/xissy/protoc
WORKDIR $GOPATH/src/github.com/xissy/protoc

RUN curl https://glide.sh/get | sh
RUN glide install
RUN cd vendor/github.com/golang/protobuf && make all
RUN cd vendor/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway && \
        glide init --non-interactive && \
        glide install && \
        go install
RUN cd vendor/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger && \
        glide init --non-interactive && \
        glide install && \
        go install
RUN cd vendor/github.com/lyft/protoc-gen-validate && \
        glide init --non-interactive && \
        glide install && \
        go install
RUN go get github.com/ckaznocha/protoc-gen-lint
RUN go get github.com/xissy/protoc-gen-swiftgrpcrx
RUN go install github.com/xissy/protoc-gen-swiftgrpcrx


#####
FROM swift:4.2.1 as swift_builder
RUN apt update && apt install -y libnghttp2-dev
ENV SWIFT_GRPC_VERSION=metadata \
    SWIFT_GRPC_REPO=xissy
WORKDIR /
RUN git clone -b ${SWIFT_GRPC_VERSION} https://github.com/${SWIFT_GRPC_REPO}/grpc-swift && \
    cd grpc-swift && \
    make


#####
FROM swift:4.2.1
RUN apt update && apt install -y libnghttp2-dev unzip

ENV PROTOC_VERSION='3.6.1' \
    GOPATH=/go \
    PATH=$PATH:/go/bin/ \
    OUTDIR=/out
RUN curl -O -L https://github.com/google/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip \
    && unzip protoc-${PROTOC_VERSION}-linux-x86_64.zip -d /usr \
    && rm -rf protoc-${PROTOC_VERSION}-linux-x86_64.zip

COPY --from=protoc_builder $GOPATH/bin $GOPATH/bin
COPY --from=protoc_builder \
        $GOPATH/src/github.com/xissy/protoc/vendor/github.com/grpc-ecosystem/grpc-gateway \
        $GOPATH/src/github.com/grpc-ecosystem/grpc-gateway
COPY --from=protoc_builder \
        $GOPATH/src/github.com/xissy/protoc/vendor/github.com/lyft/protoc-gen-validate \
        $GOPATH/src/github.com/lyft/protoc-gen-validate
COPY --from=swift_builder /grpc-swift /grpc-swift
RUN for p in protoc-gen-swift protoc-gen-swiftgrpc; do \
        ln -s /grpc-swift/${p} /usr/bin/${p}; \
    done

ENTRYPOINT ["protoc"]

