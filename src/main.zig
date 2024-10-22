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

const CommandParseError = error{ InvalidCommand, Overflow, InvalidCharacter };
fn getCmdLen(cmdHeader: []const u8) CommandParseError!usize {
    if (mem.startsWith(u8, cmdHeader, "$") == false) return error.InvalidCommand;
    return try std.fmt.parseInt(u8, cmdHeader[1..], 10);
}

fn getNextToken(tokens: *mem.TokenIterator(u8, .sequence), processedTokens: *usize, tokenCount: *const usize) ![]const u8 {
    const maybeToken = tokens.next();
    if (maybeToken == null and processedTokens.* < tokenCount.*) return error.InvalidRequest;
    processedTokens.* += 1;
    return maybeToken.?;
}

fn checkTokenLen(token: []const u8, cmdLen: usize) CommandParseError!void {
    if (token.len != cmdLen) {
        return error.InvalidCommand;
    }
    return;
}

fn getResponse(tokens: *mem.TokenIterator(u8, .sequence), tokenCount: *const usize, map: *std.StringHashMap([]const u8)) ![]const u8 {
    var processedTokens: usize = 0;
    while (processedTokens < tokenCount.*) {
        var headerToken: []const u8 = try getNextToken(tokens, &processedTokens, tokenCount);
        var tokenLen: usize = try getCmdLen(headerToken);
        var token: []const u8 = try getNextToken(tokens, &processedTokens, tokenCount);
        try checkTokenLen(token, tokenLen);
        if (std.ascii.eqlIgnoreCase(token, "PING")) {
            return "PONG";
        } else if (std.ascii.eqlIgnoreCase(token, "ECHO")) {
            headerToken = try getNextToken(tokens, &processedTokens, tokenCount);
            tokenLen = try getCmdLen(headerToken);
            token = try getNextToken(tokens, &processedTokens, tokenCount);
            try checkTokenLen(token, tokenLen);
            return token;
        } else if (std.ascii.eqlIgnoreCase(token, "SET")) {
            const keyHeader = try getNextToken(tokens, &processedTokens, tokenCount);
            const keyLen = try getCmdLen(keyHeader);
            const key = try getNextToken(tokens, &processedTokens, tokenCount);
            try checkTokenLen(key, keyLen);
            const valHeader = try getNextToken(tokens, &processedTokens, tokenCount);
            const valLen = try getCmdLen(valHeader);
            const val = try getNextToken(tokens, &processedTokens, tokenCount);
            try checkTokenLen(val, valLen);
            map.put(key, val) catch return "-ERROR\r\n";
            return "+OK";
        } else if (std.ascii.eqlIgnoreCase(token, "GET")) {
            const keyHeader = try getNextToken(tokens, &processedTokens, tokenCount);
            const keyLen = try getCmdLen(keyHeader);
            const key = try getNextToken(tokens, &processedTokens, tokenCount);
            try checkTokenLen(key, keyLen);
            const maybeVal = map.get(key);
            if (maybeVal == null) {
                return "$-1";
            }
            return maybeVal.?;
        }
    }
    return "-ERROR\r\n";
}

const RequestParseError = HeaderParseError || error{InvalidRequest} || CommandParseError;
fn handleRequest(req: *[512]u8, map: *std.StringHashMap([]const u8)) RequestParseError![]const u8 {
    var tokens: mem.TokenIterator(u8, .sequence) = tokenizeReq(req);
    const cmdCount = try parseHeader(tokens.next());
    const tokenCount = cmdCount * 2;
    return getResponse(&tokens, &tokenCount, map) catch return "-ERROR\r\n";
}

fn handleClient(conn: net.Server.Connection, alloc: *mem.Allocator) !void {
    defer conn.stream.close();
    var map = std.StringHashMap([]const u8).init(alloc.*);
    defer map.deinit();
    while (true) {
        var req: [512]u8 = undefined;
        const bytesRead = try readFromStream(conn, &req);
        if (bytesRead == 0) break;
        const res = handleRequest(&req, &map) catch |err| {
            print("Error: {any}", .{err});
            _ = try conn.stream.write("-ERROR\r\n");
            return;
        };
        try std.fmt.format(conn.stream.writer(), "${d}\r\n{s}\r\n", .{ res.len, res });
        print("Res: {s}\n", .{res});
    }
    print("client handled, closing stream\n", .{});
}

fn listenForClient(server: *net.Server) !net.Server.Connection {
    return try server.*.accept();
}

pub fn main() !void {
    var arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var alloc = arena_alloc.allocator();
    defer arena_alloc.deinit();

    const addr = try net.Address.parseIp("127.0.0.1", 6379);

    var server: net.Server = try net.Address.listen(addr, .{ .reuse_address = true });
    defer server.deinit();

    while (true) {
        const clientConn: net.Server.Connection = try listenForClient(&server);
        const thread = try std.Thread.spawn(.{}, handleClient, .{ clientConn, &alloc });
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
