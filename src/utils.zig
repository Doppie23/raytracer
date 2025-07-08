const std = @import("std");

extern fn _print(ptr: [*]const u8, len: usize) void;

pub fn print(comptime fmt: []const u8, args: anytype) void {
    const gpa = std.heap.wasm_allocator;
    const string = std.fmt.allocPrint(gpa, fmt, args) catch unreachable;
    defer gpa.free(string);
    _print(string.ptr, string.len);
}
