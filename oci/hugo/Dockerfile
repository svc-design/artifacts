FROM artifact.onwalk.net/public/alpine-glibc:2.34 as prod

ENV HUGO_VERSION 0.59.1
ENV HUGO_BINARY hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz

RUN apk --no-cache add libstdc++ ca-certificates wget \
 && wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_BINARY} \
 && tar xzf ${HUGO_BINARY} \
 && rm -r ${HUGO_BINARY} \
 && mv hugo /usr/bin

VOLUME /opt/cache
VOLUME /opt/destination
VOLUME /opt/source

EXPOSE 8080

ENTRYPOINT ["hugo",\
           "server",\
           "--cacheDir", "/opt/cache",\
           "--destination", "/opt/destination",\
           "--source", "/opt/source",\
           "--minify",\
           "--bind", "0.0.0.0",\
           "--port", "80"\
]
