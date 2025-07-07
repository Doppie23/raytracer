const std = @import("std");

const gl = struct {
    const COLOR_BUFFER_BIT = 16384;
    const VERTEX_SHADER = 35633;
    const FRAGMENT_SHADER = 35632;

    extern fn compileShader(ptr: [*]const u8, len: usize, shaderType: usize) usize;
    extern fn createProgram(vertexShaderIdx: usize, fragmentShaderIdx: usize) usize;
    extern fn useProgram(programIdx: usize) void;
    extern fn createBufferAndBind(programIdx: usize, dataPtr: [*]const f32, dataLen: usize, dataSize: usize, attPtr: [*]const u8, attLen: usize) void;
    extern fn drawArrays(count: usize) void;

    extern fn clearColor(r: f32, g: f32, b: f32, a: f32) void;
    extern fn clear(color: usize) void;
};

extern fn _print(ptr: [*]const u8, len: usize) void;

fn print(comptime fmt: []const u8, args: anytype) void {
    const gpa = std.heap.wasm_allocator;
    const string = std.fmt.allocPrint(gpa, fmt, args) catch unreachable;
    defer gpa.free(string);
    _print(string.ptr, string.len);
}

export fn init() void {
    const vertex =
        \\ attribute vec3 a_Position;
        \\ attribute vec2 a_Uv;
        \\ varying highp vec2 v_Uv;
        \\ void main() {
        \\     gl_Position = vec4(a_Position, 1.0);
        \\     v_Uv = a_Uv;
        \\ }
    ;
    const fragment =
        \\ varying highp vec2 v_Uv;
        \\ void main() {
        \\     gl_FragColor = vec4(v_Uv, 0.0, 1.0);
        \\ }
    ;

    const vertices_count = 4;
    const vertices = [_]f32{
        -1.0, -1.0, 0.0,
        1.0,  -1.0, 0.0,
        -1.0, 1.0,  0.0,
        1.0,  1.0,  0.0,
    };

    const uvs = [_]f32{
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,
    };

    const vertex_idx = gl.compileShader(vertex.ptr, vertex.len, gl.VERTEX_SHADER);

    const fragment_idx = gl.compileShader(fragment.ptr, fragment.len, gl.FRAGMENT_SHADER);

    const program = gl.createProgram(vertex_idx, fragment_idx);
    gl.useProgram(program);

    const pos = "a_Position";
    gl.createBufferAndBind(program, &vertices, vertices.len, 3, pos.ptr, pos.len);

    const uv = "a_Uv";
    gl.createBufferAndBind(program, &uvs, uvs.len, 2, uv.ptr, uv.len);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.drawArrays(vertices_count);
}
