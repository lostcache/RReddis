const std = @import("std");
const net = std.net;
const print = std.debug.print;

pub fn main() !void {
    const addr = try net.Address.parseIp("127.0.0.1", 6379);

    var server: net.Server = try net.Address.listen(addr, .{});
    defer server.deinit();

    const conn: net.Server.Connection = try server.accept();

    while (true) {
        var buf: [4096]u8 = undefined;
        const n = try conn.stream.read(buf[0..]);
        if (n == 0) break;
        _ = try conn.stream.write(buf[0..n]);
    }
}
