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
    const cmdLen2 = getCmdLen(cmdHeader2) catch |err| err;
    try std.testing.expect(cmdLen2 == error.InvalidCommand);

    const cmdHeader3 = "$abc";
    const cmdLen3 = getCmdLen(cmdHeader3) catch |err| err;
    try std.testing.expect(cmdLen3 == error.InvalidCommand);

    const cmdHeader4 = "";
    const cmdLen4 = getCmdLen(cmdHeader4) catch |err| err;
    try std.testing.expect(cmdLen4 == error.InvalidCommand);

    const cmdHeader5 = "$123";
    const cmdLen5 = getCmdLen(cmdHeader5) catch unreachable;
    try std.testing.expect(cmdLen5 == 123);
}

test "test getNextToken" {
    var text = "token1 token2 token3";
    const buffer = text[0..];

    var tokenizer = std.mem.tokenizeSequence(u8, buffer, " ");
    var processedTokens: usize = 0;

    const token1 = getNextToken(&tokenizer, &processedTokens) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token1, "token1"));

    const token2 = getNextToken(&tokenizer, &processedTokens) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token2, "token2"));

    const token3 = getNextToken(&tokenizer, &processedTokens) catch unreachable;
    try std.testing.expect(std.mem.eql(u8, token3, "token3"));

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

test "test handleECHOReq" {
    var tokens1 = std.mem.tokenizeSequence(u8, "$3 123", " ");
    var processedTokens1: usize = 0;
    const result1 = try handleECHOReq(&tokens1, &processedTokens1);
    try std.testing.expectEqualStrings("123", result1);
}
