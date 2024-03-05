# Builder stage
FROM alpine:latest AS builder

WORKDIR /src/

RUN apk add --no-cache git gcc musl-dev go                         && \
    export GOPATH=/src/go && mkdir -pv /src/go/bin/                && \
    git clone https://github.com/GoogleContainerTools/kaniko.git   && \
    cd kaniko && go install ./...

# Final image
FROM alpine:latest AS prod

WORKDIR /src/

COPY --from=builder /src/go/bin/executor /kaniko/
COPY setup-kaniko-auth.sh /kaniko/setup-kaniko-auth.sh
RUN  apk --no-cache add ca-certificates git && \
     chmod +x /kaniko/setup-kaniko-auth.sh

ENTRYPOINT ["/bin/sh"]
