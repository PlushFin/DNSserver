const std = @import("std");

pub const DnsHeader = struct {
    id: u16,
    flags: u16,
    qdcount: u16,
    ancount: u16,
    nscount: u16,
    arcount: u16,

    pub fn parse(packet: []const u8) DnsHeader {
        return .{
            .id = std.mem.readInt(u16, packet[0..2], .big),
            .flags = std.mem.readInt(u16, packet[2..4], .big),
            .qdcount = std.mem.readInt(u16, packet[4..6], .big),
            .ancount = std.mem.readInt(u16, packet[6..8], .big),
            .nscount = std.mem.readInt(u16, packet[8..10], .big),
            .arcount = std.mem.readInt(u16, packet[10..12], .big),
        };
    }

    pub fn isQuery(self: DnsHeader) bool {
        return (self.flags >> 15) & 1 == 0;
    }

    pub fn write(self: DnsHeader, out: []u8) void {
        std.mem.writeInt(u16, out[0..2], self.id, .big);
        std.mem.writeInt(u16, out[2..4], self.flags, .big);
        std.mem.writeInt(u16, out[4..6], self.qdcount, .big);
        std.mem.writeInt(u16, out[6..8], self.ancount, .big);
        std.mem.writeInt(u16, out[8..10], self.nscount, .big);
        std.mem.writeInt(u16, out[10..12], self.arcount, .big);
    }
};
