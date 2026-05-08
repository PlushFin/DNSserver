const std = @import("std");
const Io = std.Io;
const net = Io.net;

const Rcode = @import("rcode.zig");
const makeFlags = Rcode.makeFlags;
const DnsHeader = @import("dnsHeader.zig").DnsHeader;

const records = std.StaticStringMap([4]u8).initComptime(.{
    .{ "example.com.", .{ 1, 2, 3, 4 } },
    .{ "test.com.", .{ 5, 6, 7, 8 } },
});

const DnsType = enum(u16) {
    TYPE_A = 1,
    TYPE_CNAME = 5,
    TYPE_AAAA = 28,
};
fn makeDNSTYPE(dnsType: DnsType) u16 {
    return @intFromEnum(dnsType);
}

const CLASS_IN: u16 = 1;

pub fn processQuery(packet: []const u8, out: []u8) !usize {
    if (packet.len < 12) return error.PacketTooSmall;

    const header = DnsHeader.parse(packet);
    if (!header.isQuery()) return error.NotAQuery;
    if (header.qdcount == 0) return error.NoQuestion;

    // --- Parse question name (starts at byte 12) ---
    var name_buf: [256]u8 = undefined;
    var name_len: usize = 0;
    var pos: usize = 12;

    while (pos < packet.len) {
        const label_len = packet[pos];
        pos += 1;

        if (label_len == 0) break;
        if (name_len + label_len + 1 > name_buf.len) return error.NameTooLong;

        @memcpy(name_buf[name_len .. name_len + label_len], packet[pos .. pos + label_len]);
        name_len += label_len;
        name_buf[name_len] = '.';
        name_len += 1;
        pos += label_len;
    }

    const qtype = std.mem.readInt(u16, packet[pos..][0..2], .big);
    const qclass = std.mem.readInt(u16, packet[pos + 2 ..][0..2], .big);
    pos += 4;

    const question_end = pos;
    const name = name_buf[0..name_len];

    // --- Copy question section verbatim ---
    @memcpy(out[12..pos], packet[12..pos]);

    if (qclass != CLASS_IN) {
        const response_header = DnsHeader{
            .id = header.id,
            .flags = Rcode.makeFlags(.NotImp),
            .qdcount = 1,
            .ancount = 0,
            .nscount = 0,
            .arcount = 0,
        };
        response_header.write(out);
        return question_end;
    }

    const dns_type = std.enums.fromInt(DnsType, qtype) orelse {
        const response_header = DnsHeader{
            .id = header.id,
            .flags = Rcode.makeFlags(.NotImp),
            .qdcount = 1,
            .ancount = 0,
            .nscount = 0,
            .arcount = 0,
        };
        response_header.write(out);
        return question_end;
    };

    switch (dns_type) {
        .TYPE_A => {
            if (records.get(name)) |ip| {
                const response_header = DnsHeader{
                    .id = header.id,
                    .flags = Rcode.makeFlags(.NoError),
                    .qdcount = 1,
                    .ancount = 1,
                    .nscount = 0,
                    .arcount = 0,
                };
                response_header.write(out);

                out[pos] = 0xC0;
                out[pos + 1] = 0x0C;
                pos += 2;

                std.mem.writeInt(u16, out[pos..][0..2], makeDNSTYPE(.TYPE_A), .big);
                pos += 2;
                std.mem.writeInt(u16, out[pos..][0..2], CLASS_IN, .big);
                pos += 2;
                std.mem.writeInt(u32, out[pos..][0..4], 300, .big);
                pos += 4;
                std.mem.writeInt(u16, out[pos..][0..2], 4, .big);
                pos += 2;
                @memcpy(out[pos .. pos + 4], &ip);
                pos += 4;

                return pos;
            } else {
                const response_header = DnsHeader{
                    .id = header.id,
                    .flags = Rcode.makeFlags(.NxDomain),
                    .qdcount = 1,
                    .ancount = 0,
                    .nscount = 0,
                    .arcount = 0,
                };
                response_header.write(out);
                return question_end;
            }
        },
        else => {
            const response_header = DnsHeader{
                .id = header.id,
                .flags = Rcode.makeFlags(.NotImp),
                .qdcount = 1,
                .ancount = 0,
                .nscount = 0,
                .arcount = 0,
            };
            response_header.write(out);
            return question_end;
        },
    }
}

fn workerLoop(io: Io, socket: net.Socket) void {
    var buf: [512]u8 = undefined;

    while (true) {
        const msg = socket.receive(io, &buf) catch return;

        var response: [512]u8 = undefined;
        const response_len = processQuery(msg.data, &response) catch continue;

        socket.send(io, &msg.from, response[0..response_len]) catch continue;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const port: u16 = blk: {
        const env_port = init.environ_map.get("DNS_PORT") orelse break :blk 2053;
        break :blk std.fmt.parseInt(u16, env_port, 10) catch 2053;
    };
    const address = net.IpAddress{ .ip4 = net.Ip4Address.unspecified(port) };
    const socket = try address.bind(io, .{ .mode = .dgram });
    defer socket.close(io);

    const cpu_count = try std.Thread.getCpuCount();
    std.log.info("Starting {d} workers on UDP port {d}", .{ cpu_count, port });

    const threads = try allocator.alloc(std.Thread, cpu_count);
    defer allocator.free(threads);

    for (threads) |*t| {
        t.* = try std.Thread.spawn(.{}, workerLoop, .{ io, socket });
    }
    for (threads) |t| t.join();
}
