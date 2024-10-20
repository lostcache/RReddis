const std = @import("std");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

fn readFromStream(conn: net.Server.Connection, buf: *[512]u8) !usize {
    return try conn.stream.read(buf);
}

fn tokenizeReq(buf: *[512]u8) mem.TokenIterator(u8, .sequence) {
    return mem.tokenizeSequence(u8, buf, "\r\n");
}

pub fn handleClient(conn: net.Server.Connection) !void {
    defer conn.stream.close();
    while (true) {
        var req: [512]u8 = undefined;
        const bytesRead = try readFromStream(conn, &req);
        if (bytesRead == 0) break;
        var tokens: mem.TokenIterator(u8, .sequence) = tokenizeReq(&req);
        while (tokens.next()) |token| {
            print("token: {s}\n", .{token});
        }
        _ = try conn.stream.write("OK\r\n");
    }
}

pub fn listenForClient(server: *net.Server) !net.Server.Connection {
    return try server.*.accept();
}

pub fn main() !void {
    const addr = try net.Address.parseIp("127.0.0.1", 6379);

    var server: net.Server = try net.Address.listen(addr, .{});
    defer server.deinit();

    while (true) {
        const clientConn: net.Server.Connection = try listenForClient(&server);
        const thread = try std.Thread.spawn(.{}, handleClient, .{clientConn});
        thread.detach();
    }
}
