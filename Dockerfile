FROM debian:bookworm-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq xz-utils \
    && rm -rf /var/lib/apt/lists/*

ARG ZIG_VERSION=0.16.0

WORKDIR /tmp
RUN ZIG_URL="$(curl -fsSL https://ziglang.org/download/index.json | jq -r --arg v "$ZIG_VERSION" '.[$v]."x86_64-linux".tarball')" \
    && test -n "$ZIG_URL" \
    && test "$ZIG_URL" != "null" \
    && curl -fsSL "$ZIG_URL" -o zig.tar.xz \
    && tar -xf zig.tar.xz \
    && mv zig-*/ /opt/zig \
    && ln -s /opt/zig/zig /usr/local/bin/zig

WORKDIR /app
COPY . .
RUN zig build -Doptimize=ReleaseSafe

FROM debian:bookworm-slim AS runtime

WORKDIR /app
COPY --from=builder /app/zig-out/bin/DNS /app/DNS

ENV DNS_PORT=53
EXPOSE 53/udp

CMD ["./DNS"]
