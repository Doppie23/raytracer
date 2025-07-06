const std = @import("std");

extern fn _print(ptr: usize, len: usize) void;

fn print(comptime fmt: []const u8, args: anytype) void {
    const gpa = std.heap.wasm_allocator;
    const string = std.fmt.allocPrint(gpa, fmt, args) catch unreachable;
    defer gpa.free(string);
    _print(@intFromPtr(string.ptr), string.len);
}

export fn test_fn() i32 {
    return 123;
}

export fn add(a: i32, b: i32) i32 {
    const gpa = std.heap.wasm_allocator;

    // const alloc = gpa.allocator();

    const xs = gpa.alloc(u8, 256) catch unreachable;
    defer gpa.free(xs);

    print("tset {d} b: {d}, len: {d}", .{ a, b, xs.len });
    return a + b;
}
