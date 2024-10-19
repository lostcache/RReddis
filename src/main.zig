const std = @import("std");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

pub fn handleClient(conn: net.Server.Connection) !void {
    defer conn.stream.close();
    while (true) {
        var buf: [512]u8 = undefined;
        const n = try conn.stream.read(&buf);
        if (n == 0) break;
        var tokens: mem.TokenIterator(u8, .sequence) = mem.tokenizeSequence(u8, &buf, "\r\n");
        while (tokens.next()) |token| {
            print("token: {s}\n", .{token});
        }
        _ = try conn.stream.write("OK\r\n");
    }
}

pub fn main() !void {
    const addr = try net.Address.parseIp("127.0.0.1", 6379);

    var server: net.Server = try net.Address.listen(addr, .{});
    defer server.deinit();

    while (true) {
        const conn: net.Server.Connection = try server.accept();
        const thread = try std.Thread.spawn(.{}, handleClient, .{conn});
        thread.detach();
    }
}
