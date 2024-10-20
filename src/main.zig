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

const HeaderParseError = error{ Overflow, InvalidCharacter, MissingHeader, HeaderParseError };
fn parseHeader(maybeToken: ?[]const u8) HeaderParseError!usize {
    if (maybeToken == null) return error.MissingHeader;
    const token = maybeToken.?;
    if (mem.startsWith(u8, token, "*") == false) return error.HeaderParseError;
    return try std.fmt.parseInt(u8, token[1..], 10);
}

fn handleRequest(req: *[512]u8) ![]const u8 {
    var tokens: mem.TokenIterator(u8, .sequence) = tokenizeReq(req);
    const cmdLen = try parseHeader(tokens.next());
    const tokenLen = cmdLen * 2;
    _ = tokenLen;
    return "OK\r\n";
}

pub fn handleClient(conn: net.Server.Connection) !void {
    defer conn.stream.close();
    while (true) {
        var req: [512]u8 = undefined;
        const bytesRead = try readFromStream(conn, &req);
        if (bytesRead == 0) break;
        const res = try handleRequest(&req);
        const resBytes = try conn.stream.write(res);
        print("Served {d} bytes\nRes: {s}", .{ resBytes, res });
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

test "test parseHeader" {
    const t = std.testing;

    try t.expectError(HeaderParseError.MissingHeader, parseHeader(null));

    try t.expectError(HeaderParseError.HeaderParseError, parseHeader("abc"));

    try t.expectEqual(123, parseHeader("*123"));

    try t.expectError(HeaderParseError.InvalidCharacter, parseHeader("*abc"));
}
