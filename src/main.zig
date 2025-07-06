const std = @import("std");

const gl = struct {
    const COLOR_BUFFER_BIT = 16384;

    extern fn clearColor(r: f32, g: f32, b: f32, a: f32) void;
    extern fn clear(color: usize) void;
};

extern fn _print(ptr: usize, len: usize) void;

fn print(comptime fmt: []const u8, args: anytype) void {
    const gpa = std.heap.wasm_allocator;
    const string = std.fmt.allocPrint(gpa, fmt, args) catch unreachable;
    defer gpa.free(string);
    _print(@intFromPtr(string.ptr), string.len);
}

export fn init() void {
    // const gpa = std.heap.wasm_allocator;
    //
    // // const alloc = gpa.allocator();
    //
    // const xs = gpa.alloc(u8, 256) catch unreachable;
    // defer gpa.free(xs);

    gl.clearColor(0, 0, 1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
}
