FROM ghcr.io/ziglang/zig:master

WORKDIR /app

COPY . .

RUN zig build -Doptimize=ReleaseSafe

ENV DNS_PORT=2053

EXPOSE 2053/udp

CMD ["./zig-out/bin/DNS"]
