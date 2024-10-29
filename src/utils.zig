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
    return std.fmt.parseInt(u8, cmdHeader[1..], 10) catch return error.InvalidCommand;
}

pub fn getNextToken(tokens: *std.mem.TokenIterator(u8, .sequence), processedTokens: *usize) RequestSyntaxError![]const u8 {
    const maybeToken = tokens.next();
    if (maybeToken == null) return error.InvalidRequest;
    processedTokens.* += 1;
    return maybeToken.?;
}

pub fn checkTokenLen(token: []const u8, cmdLen: usize) RequestSyntaxError!void {
    if (token.len != cmdLen) {
        return error.InvalidCommand;
    }
    return;
}

pub fn handleECHOReq(tokens: *std.mem.TokenIterator(u8, .sequence), processedTokens: *usize) ![]const u8 {
    const headerToken = try getNextToken(tokens, processedTokens);
    const tokenLen = try getCmdLen(headerToken);
    const token = try getNextToken(tokens, processedTokens);
    try checkTokenLen(token, tokenLen);
    return token;
}

test "test parseHeader" {
    const t = std.testing;
    try t.expectError(RequestSyntaxError.MissingHeader, parseHeader(null));
    try t.expectError(RequestSyntaxError.HeaderParseError, parseHeader("abc"));
    try t.expectEqual(123, parseHeader("*123"));
    try t.expectError(RequestSyntaxError.InvalidCharacter, parseHeader("*abc"));
}

test "getCmdLen" {
    const cmdHeader1 = "$5";
    const expectedLength = 5;
    const result1 = getCmdLen(cmdHeader1) catch unreachable;
    try std.testing.expect(result1 == expectedLength);

    const cmdHeader2 = "5";
    if (getCmdLen(cmdHeader2)) |_| {
        try std.testing.expect(false);
    } else |err| {
        try std.testing.expect(err == error.InvalidCommand);
    }

    const cmdHeader3 = "$abc";
    if (getCmdLen(cmdHeader3)) |_| {
        try std.testing.expect(false);
    } else |err| {
        try std.testing.expect(err == error.InvalidCommand);
    }

    const cmdHeader4 = "";
    if (getCmdLen(cmdHeader4)) |_| {
        try std.testing.expect(false);
    } else |err| {
        try std.testing.expect(err == error.InvalidCommand);
    }

    const cmdHeader5 = "$123";
    if (getCmdLen(cmdHeader5)) |val| {
        try std.testing.expect(val == 123);
    } else |_| {
        try std.testing.expect(false);
    }
}

test "test getNextToken" {
    var text = "token1 token2 token3";
    const buffer = text[0..];

    var tokenizer = std.mem.tokenizeSequence(u8, buffer, " ");
    var processedTokens: usize = 0;

    // Test first token
    const token1 = getNextToken(&tokenizer, &processedTokens) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token1, "token1"));

    // Test second token
    const token2 = getNextToken(&tokenizer, &processedTokens) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token2, "token2"));

    // Test third token
    const token3 = getNextToken(&tokenizer, &processedTokens) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token3, "token3"));

    // Test no more tokens
    const result = getNextToken(&tokenizer, &processedTokens);
    try std.testing.expectError(error.InvalidRequest, result);
}

test "test checkTokenLen" {
    var token = "command";
    var cmdLen: usize = 7;
    try checkTokenLen(token, cmdLen);

    token = "command";
    cmdLen = 6;
    const err = checkTokenLen(token, cmdLen) catch |e| e;
    try std.testing.expect(err == error.InvalidCommand);
}
