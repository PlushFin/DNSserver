const DnsType = enum(u16) {
    TYPE_A = 1,
    TYPE_CNAME = 5,
    TYPE_AAAA = 28,
};
fn makeDNSTYPE(dnsType: DnsType) u16 {
    return @intFromEnum(dnsType);
}