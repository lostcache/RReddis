const std = @import("std");

pub const RequestSyntaxError = error{ Overflow, InvalidCharacter, MissingHeader, HeaderParseError, InvalidCommand, InvalidRequest };

pub fn parseHeader(maybeToken: ?[]const u8) RequestSyntaxError!usize {
    if (maybeToken == null) return error.MissingHeader;
    const token = maybeToken.?;
    if (std.mem.startsWith(u8, token, "*") == false) return error.HeaderParseError;
    return try std.fmt.parseInt(u8, token[1..], 10);
}

pub fn getCmdLen(cmdHeader: []const u8) RequestSyntaxError!usize {
    if (std.mem.startsWith(u8, cmdHeader, "$") == false) return error.InvalidCommand;
    return try std.fmt.parseInt(u8, cmdHeader[1..], 10);
}

pub fn getNextToken(tokens: *std.mem.TokenIterator(u8, .sequence), processedTokens: *usize, tokenCount: *const usize) RequestSyntaxError![]const u8 {
    const maybeToken = tokens.next();
    if (maybeToken == null and processedTokens.* < tokenCount.*) return error.InvalidRequest;
    processedTokens.* += 1;
    return maybeToken.?;
}

pub fn checkTokenLen(token: []const u8, cmdLen: usize) RequestSyntaxError!void {
    if (token.len != cmdLen) {
        return error.InvalidCommand;
    }
    return;
}

test "test parseHeader" {
    const t = std.testing;
    try t.expectError(RequestSyntaxError.MissingHeader, parseHeader(null));
    try t.expectError(RequestSyntaxError.HeaderParseError, parseHeader("abc"));
    try t.expectEqual(123, parseHeader("*123"));
    try t.expectError(RequestSyntaxError.InvalidCharacter, parseHeader("*abc"));
}

test "getCmdLen returns correct length for valid command header" {
    const cmdHeader = "$5";
    const expectedLength = 5;
    const result = getCmdLen(cmdHeader) catch unreachable;
    try std.testing.expect(result == expectedLength);
}

test "getCmdLen returns error for invalid command header" {
    const cmdHeader = "5";
    const result = getCmdLen(cmdHeader);
    switch (result) {
        error.InvalidCommand => {},
        else => std.testing.expect(false, "Expected error.InvalidCommand"),
    }
}

test "getCmdLen returns error for non-numeric command length" {
    const cmdHeader = "$abc";
    const result = getCmdLen(cmdHeader);
    switch (result) {
        error.InvalidCommand => {},
        else => std.testing.expect(false, "Expected error.InvalidCommand"),
    }
}

test "getCmdLen returns error for empty command header" {
    const cmdHeader = "";
    const result = getCmdLen(cmdHeader);
    switch (result) {
        error.InvalidCommand => {},
        else => std.testing.expect(false, "Expected error.InvalidCommand"),
    }
}

test "getCmdLen returns correct length for multi-digit command header" {
    const cmdHeader = "$123";
    const expectedLength = 123;
    const result = getCmdLen(cmdHeader) catch unreachable;
    try std.testing.expect(result == expectedLength);
}
