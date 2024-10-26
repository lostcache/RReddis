const std = @import("std");

pub const HeaderParseError = error{ Overflow, InvalidCharacter, MissingHeader, HeaderParseError };
pub fn parseHeader(maybeToken: ?[]const u8) HeaderParseError!usize {
    if (maybeToken == null) return error.MissingHeader;
    const token = maybeToken.?;
    if (std.mem.startsWith(u8, token, "*") == false) return error.HeaderParseError;
    return try std.fmt.parseInt(u8, token[1..], 10);
}

test "test parseHeader" {
    const t = std.testing;
    try t.expectError(HeaderParseError.MissingHeader, parseHeader(null));
    try t.expectError(HeaderParseError.HeaderParseError, parseHeader("abc"));
    try t.expectEqual(123, parseHeader("*123"));
    try t.expectError(HeaderParseError.InvalidCharacter, parseHeader("*abc"));
}

pub const CommandParseError = error{ InvalidCommand, Overflow, InvalidCharacter };
pub fn getCmdLen(cmdHeader: []const u8) CommandParseError!usize {
    if (std.mem.startsWith(u8, cmdHeader, "$") == false) return error.InvalidCommand;
    return try std.fmt.parseInt(u8, cmdHeader[1..], 10);
}

pub fn getNextToken(tokens: *std.mem.TokenIterator(u8, .sequence), processedTokens: *usize, tokenCount: *const usize) ![]const u8 {
    const maybeToken = tokens.next();
    if (maybeToken == null and processedTokens.* < tokenCount.*) return error.InvalidRequest;
    processedTokens.* += 1;
    return maybeToken.?;
}

pub fn checkTokenLen(token: []const u8, cmdLen: usize) CommandParseError!void {
    if (token.len != cmdLen) {
        return error.InvalidCommand;
    }
    return;
}
