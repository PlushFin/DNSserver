pub const RCodeType = enum(u4) {
    NoError = 0, // found the record
    FormErr = 1, // query packet was malformed
    ServFail = 2, // server had an internal error
    NxDomain = 3, // name does not exist
    NotImp = 4, //do not support this query type or class
    Refused = 5, // refuse to answer this query
    pub fn flags(self: @This()) u16 {
        return @as(u16, @intFromEnum(self));
    }
};
