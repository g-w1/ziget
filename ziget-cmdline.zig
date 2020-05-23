const std = @import("std");
const ziget = @import("./ziget.zig");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = &arena.allocator;

fn printError(comptime fmt: []const u8, args: var) void {
  std.debug.warn("Error: " ++ fmt ++ "\n", args);
}

fn usage() void {
    std.debug.warn(
      \\Usage: ziget [-options] <url>
      \\Options:
      \\  --max-redirs <num>   maximum number of redirects, default is 50
      , .{});
}

pub fn main() anyerror!u8 {
    var args = try std.process.argsAlloc(allocator);
    if (args.len <= 1) {
      usage();
      return 1; // error exit code
    }
    args = args[1..];

    var maxRedirects : u16 = 50;
    {
        var newArgsLength : usize = 0;
        defer args.len = newArgsLength;
        var i : usize = 0;
        while (i < args.len) : (i += 1) {
            var arg = args[i];
            if (!std.mem.startsWith(u8, arg, "-")) {
                args[newArgsLength] = arg;
                newArgsLength += 1;
            } else if (std.mem.eql(u8, arg, "--max-redirs")) {
                @panic("--max-redirs not implemented");
            } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                usage();
                return 1;
            } else {
                printError("unknown option '{}'", .{arg});
                return 1;
            }
        }
    }

    if (args.len != 1) {
        printError("expected 1 URL but got {} arguments", .{args.len});
        return 1;
    }
    const urlString = args[0];
    const url = try ziget.url.parseUrl(urlString);
    ziget.request.download(allocator, url) catch |e| switch (e) {
        error.UnknownUrlScheme => {
            printError("unknown url scheme '{}'", .{url.schemeString()});
            return 1;
        },
        else => return e,
    };
    return 0;
}