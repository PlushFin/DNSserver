# DNS

Experimental authoritative-style DNS server in Zig (`std.Io`). Static compile-time zone data.

**Transport:** the server only opens a **UDP** datagram socket (`bind` with `.dgram` in `main.zig`). There is **no TCP** listener; large responses and TCP-only clients are not supported yet.

## Feature list

Use **`- [x]`** = implemented, **`- [ ]`** = not implemented.

### DNS record types (answer behavior)

- [x] **A** (type 1) — authoritative-style answers from the in-memory map; unknown name → NXDOMAIN
- [ ] **CNAME** (type 5) — enum exists; queries return **NOTIMP**, no chain resolution
- [ ] **AAAA** (type 28) — enum exists; queries return **NOTIMP**
- [ ] **NS**, **MX**, **TXT**, **SOA**, **PTR**, … — any other QTYPE → **NOTIMP**

### DNS classes

- [x] **IN** (class 1) — only class that can yield an **A** answer
- [x] Non-**IN** classes — **NOTIMP** (explicit rejection, not full class support)

### Transport & message limits

- [x] **UDP** DNS
- [ ] **TCP** DNS (RFC 7766-style streaming)
- [ ] **EDNS0** (OPT pseudo-section)

### Parsing & strictness

- [x] **Uncompressed** QNAME labels in the question section
- [ ] **Compressed QNAME** (pointer labels per RFC 1035) on receive
- [ ] **Multiple questions** (QDCount ≠ 1) — only one question section is parsed end-to-end

### Runtime & packaging

- [x] Configurable **UDP port** via **`DNS_PORT`** (default **53**)
- [x] **Multi-worker** pool (one async worker per CPU, shared socket)
- [x] **`zig build`** / **`zig build run`** (Zig **0.16**, see `mise.toml`)
- [x] **`Dockerfile`** multi-stage (**ReleaseSafe**)
- [x] **CI/CD**: push to `main` → **GHCR** image + **Bunny Magic Containers** update (`.github/workflows/Deploy.yml`)

### Zone & codebase

- [x] **Compile-time** static zone (`StaticStringMap` in `main.zig`)
- [ ] **Runtime zone** load (file, env, Redis, etc.)
- [ ] **`root.zig` / `dnstype.zig`** unified with the server as one library surface
- [ ] **Automated DNS packet tests** (beyond template `zig build test`)

---

## Quick start

```bash
zig build
zig build run
# DNS_PORT=5353 zig build run   # non-privileged port
```

**Docker**

```bash
docker build -t dns .
docker run --rm -p 5353:5353/udp -e DNS_PORT=5353 dns
```

**Try**

```bash
dig @127.0.0.1 -p 5353 plushfin.com A
```

Use the host/port your server actually binds.
