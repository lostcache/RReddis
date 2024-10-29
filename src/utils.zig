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

test "getCmdLen" {
    var cmdHeader = "$5";
    const expectedLength = 5;
    var result = getCmdLen(cmdHeader) catch unreachable;
    try std.testing.expect(result == expectedLength);

    cmdHeader = "5";
    result = getCmdLen(cmdHeader);
    switch (result) {
        error.InvalidCommand => {},
        else => std.testing.expect(false, "Expected error.InvalidCommand"),
    }

    cmdHeader = "$abc";
    result = getCmdLen(cmdHeader);
    switch (result) {
        error.InvalidCommand => {},
        else => std.testing.expect(false, "Expected error.InvalidCommand"),
    }

    cmdHeader = "";
    result = getCmdLen(cmdHeader);
    switch (result) {
        error.InvalidCommand => {},
        else => std.testing.expect(false, "Expected error.InvalidCommand"),
    }

    cmdHeader = "$123";
    expectedLength = 123;
    result = getCmdLen(cmdHeader) catch unreachable;
    try std.testing.expect(result == expectedLength);
}

test "test getNextToken" {
    var text = "token1 token2 token3";
    const buffer = text[0..];

    var tokenizer = std.mem.tokenize(buffer, " ");
    var processedTokens: usize = 0;
    const tokenCount: usize = 3;

    // Test first token
    const token1 = getNextToken(&tokenizer, &processedTokens, &tokenCount) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token1, "token1"));

    // Test second token
    const token2 = getNextToken(&tokenizer, &processedTokens, &tokenCount) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token2, "token2"));

    // Test third token
    const token3 = getNextToken(&tokenizer, &processedTokens, &tokenCount) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token3, "token3"));

    // Test no more tokens
    const result = getNextToken(&tokenizer, &processedTokens, &tokenCount);
    try std.testing.expectError(error.InvalidRequest, result);
}

test "test checkTokenLen" {
    var token = "command";
    var cmdLen = 7;
    try checkTokenLen(token, cmdLen);

    token = "command";
    cmdLen = 6;
    const err = checkTokenLen(token, cmdLen) catch |e| e;
    try std.testing.expect(err == error.InvalidCommand);
}
