const std = @import("std");

extern fn _print(ptr: usize, len: usize) void;

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [8192]u8 = undefined;
    const string = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    _print(@intFromPtr(string.ptr), string.len);
}

export fn test_fn() i32 {
    return 123;
}

export fn add(a: i32, b: i32) i32 {
    // var gpa = std.heap.wasm_allocator(.{}).init;
    // const alloc: std.mem.Allocator = .{
    //     .ptr = undefined,
    //     .vtable = &std.heap.WasmAllocator.vtable,
    // };
    // // defer gpa.deinit();
    //
    // // var alloc = gpa.allocator();
    //
    // _ = alloc.alloc(u8, 256) catch unreachable;

    print("tset {d} b: {d}", .{ a, b });
    return a + b;
}
