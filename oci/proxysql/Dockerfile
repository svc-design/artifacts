
# ---- build stage ----
FROM ubuntu:22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

# 构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gawk git ca-certificates pkg-config \
    autoconf automake libtool cmake \
    libssl-dev zlib1g-dev libaio-dev default-libmysqlclient-dev \
    libgnutls28-dev libcurl4-openssl-dev \
    bison flex libncurses5-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# 完整 clone，保留 tag（不要 --depth=1）
RUN git clone --branch v3.0.2 https://github.com/sysown/proxysql.git proxysql
WORKDIR /src/proxysql

# --- 禁用 jemalloc ---
RUN sed -ri 's/^(.*\bjemalloc\b.*:.*)$/\1\n\t@echo "skip building jemalloc"/' deps/Makefile || true \
 && sed -ri 's@-I\.\./deps/jemalloc/jemalloc/include/jemalloc@@g' src/Makefile lib/Makefile || true \
 && sed -ri 's/\s-ljemalloc(\s|$)/ /g' src/Makefile lib/Makefile || true

# 构建安装
RUN make cleanall || true \
 && make -j"$(nproc)" \
 && make install

# ---- runtime stage ----
FROM ubuntu:22.04

# 避免 jemalloc 被加载
ENV LD_PRELOAD=""

# 只拷贝二进制和配置文件
COPY --from=build /usr/local/bin/proxysql /usr/bin/proxysql
COPY --from=build /usr/local/etc/proxysql.cnf /etc/proxysql.cnf

EXPOSE 6032 6033 6080

ENTRYPOINT ["/usr/bin/proxysql", "-f", "-c", "/etc/proxysql.cnf"]
