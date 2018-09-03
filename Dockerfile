FROM alpine:3.8 as protoc_builder
RUN apk update && apk add ca-certificates && rm -rf /var/cache/apk/*
RUN apk add --no-cache build-base autoconf automake libtool make curl git go glide python2

ENV PROTOBUF_TAG='v3.6.1' \
    GOPATH=/go \
    PATH=$PATH:/go/bin/ \
    OUTDIR=/out

RUN git clone https://github.com/google/protobuf -b $PROTOBUF_TAG --depth 1
WORKDIR ./protobuf
RUN autoreconf -f -i -Wall,no-obsolete && \
    ./configure --prefix=/usr --enable-static=no && \
    make -j2 && make install DESTDIR=${OUTDIR}
RUN find ${OUTDIR} -name "*.a" -delete -or -name "*.la" -delete

RUN mkdir -p /go/bin
COPY . $GOPATH/src/github.com/xissy/protoc
WORKDIR $GOPATH/src/github.com/xissy/protoc
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
RUN go get github.com/ckaznocha/protoc-gen-lint


FROM alpine:3.8
RUN apk add --no-cache libstdc++

ENV GOPATH=/go \
    PATH=$PATH:/go/bin/ \
    OUTDIR=/out

COPY --from=protoc_builder ${OUTDIR} /
COPY --from=protoc_builder $GOPATH/bin $GOPATH/bin
COPY --from=protoc_builder \
        $GOPATH/src/github.com/xissy/protoc/vendor/github.com/grpc-ecosystem/grpc-gateway \
        $GOPATH/src/github.com/grpc-ecosystem/grpc-gateway

ENTRYPOINT ["protoc"]
