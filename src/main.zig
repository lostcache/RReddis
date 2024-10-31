const std = @import("std");
const print = std.debug.print;
const utils = @import("utils.zig");

fn getResponse(tokens: *std.mem.TokenIterator(u8, .sequence), tokenCount: *const usize, map: *std.StringHashMap([]const u8), alloc: *std.mem.Allocator) ![]const u8 {
    var processedTokens: usize = 0;
    while (processedTokens < tokenCount.*) {
        const headerToken: []const u8 = try utils.getNextToken(tokens, &processedTokens);
        const tokenLen: usize = try utils.getCmdLen(headerToken);
        const token: []const u8 = try utils.getNextToken(tokens, &processedTokens);
        try utils.checkTokenLen(token, tokenLen);
        if (std.ascii.eqlIgnoreCase(token, "PING")) {
            return "PONG";
        } else if (std.ascii.eqlIgnoreCase(token, "ECHO")) {
            return try utils.handleECHOReq(tokens, &processedTokens);
        } else if (std.ascii.eqlIgnoreCase(token, "SET")) {
            try utils.handleSETReq(tokens, &processedTokens, map, alloc);
            return "OK";
        } else if (std.ascii.eqlIgnoreCase(token, "GET")) {
            return try utils.handleGETReq(tokens, &processedTokens, map);
        }
    }
    return "-ERROR\r\n";
}

fn handleRequest(req: *[512]u8, map: *std.StringHashMap([]const u8), alloc: *std.mem.Allocator) utils.RequestSyntaxError![]const u8 {
    var tokens: std.mem.TokenIterator(u8, .sequence) = std.mem.tokenizeSequence(u8, req, "\r\n");
    const cmdCount = try utils.parseHeader(tokens.next());
    const tokenCount = cmdCount * 2;
    const res = getResponse(&tokens, &tokenCount, map, alloc) catch return "-ERROR\r\n";
    return res;
}

fn handleClient(conn: *std.net.Server.Connection, map: *std.StringHashMap([]const u8), alloc: *std.mem.Allocator) !void {
    defer conn.stream.close();
    while (true) {
        var req: [512]u8 = undefined;
        const bytesRead = try conn.stream.read(&req);
        if (bytesRead == 0) break;
        const res = handleRequest(&req, map, alloc) catch |err| {
            print("Error: {any}", .{err});
            _ = try conn.stream.write("-ERROR\r\n");
            return;
        };
        try std.fmt.format(conn.stream.writer(), "${d}\r\n{s}\r\n", .{ res.len, res });
    }
    print("client handled, closing stream\n", .{});
}

fn listenForClient(server: *std.net.Server) !std.net.Server.Connection {
    return try server.*.accept();
}

pub fn main() !void {
    var arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var alloc = arena_alloc.allocator();
    defer arena_alloc.deinit();

    const addr = try std.net.Address.parseIp("127.0.0.1", 6379);

    var server: std.net.Server = try std.net.Address.listen(addr, .{ .reuse_address = true });
    defer server.deinit();

    var map = std.StringHashMap([]const u8).init(alloc);
    defer map.deinit();

    while (true) {
        var clientConn: std.net.Server.Connection = try listenForClient(&server);
        const thread = try std.Thread.spawn(.{}, handleClient, .{ &clientConn, &map, &alloc });
        thread.detach();
    }
}
