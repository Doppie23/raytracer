const std = @import("std");

fn Vec3(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        z: T,
    };
}

const gl = struct {
    const COLOR_BUFFER_BIT = 16384;
    const VERTEX_SHADER = 35633;
    const FRAGMENT_SHADER = 35632;

    extern fn compileShader(ptr: [*]const u8, len: usize, shaderType: usize) usize;
    extern fn createProgram(vertexShaderIdx: usize, fragmentShaderIdx: usize) usize;
    extern fn useProgram(programIdx: usize) void;
    extern fn createBufferAndBind(programIdx: usize, dataPtr: [*]const f32, dataLen: usize, dataSize: usize, attPtr: [*]const u8, attLen: usize) void;
    extern fn drawArrays(count: usize) void;
    extern fn uniform3f(programIdx: usize, uniformPtr: [*]const u8, uniformLen: usize, x: f32, y: f32, z: f32) void;
    extern fn uniform1f(programIdx: usize, uniformPtr: [*]const u8, uniformLen: usize, x: f32) void;
    extern fn uniform1i(programIdx: usize, uniformPtr: [*]const u8, uniformLen: usize, x: i32) void;

    extern fn clearColor(r: f32, g: f32, b: f32, a: f32) void;
    extern fn clear(color: usize) void;

    fn uniform(comptime T: type, programIdx: usize, name: []const u8, value: T) void {
        if (T == Vec3(f32)) {
            return uniform3f(programIdx, name.ptr, name.len, value.x, value.y, value.z);
        }
        if (T == f32) {
            return uniform1f(programIdx, name.ptr, name.len, value);
        }
        if (T == i32) {
            return uniform1i(programIdx, name.ptr, name.len, value);
        }

        @compileError("Unsupported uniform type");
    }
};

extern fn _print(ptr: [*]const u8, len: usize) void;

fn print(comptime fmt: []const u8, args: anytype) void {
    const gpa = std.heap.wasm_allocator;
    const string = std.fmt.allocPrint(gpa, fmt, args) catch unreachable;
    defer gpa.free(string);
    _print(string.ptr, string.len);
}

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

const Sphere = struct {
    position: Vec3(f32),
    radius: f32,
};

const Camera = struct {
    position: Vec3(f32),
    p0: Vec3(f32),
    p1: Vec3(f32),
    p2: Vec3(f32),

    fn init() Camera {
        return .{
            .position = Vec3(f32){ .x = 0, .y = 0, .z = -2 },
            .p0 = Vec3(f32){ .x = -1, .y = 1, .z = 0 },
            .p1 = Vec3(f32){ .x = 1, .y = 1, .z = 0 },
            .p2 = Vec3(f32){ .x = -1, .y = 0, .z = 0 },
            // (0; 0,5; -2)
            // (-0,5; 0,84305316; -1,0349569)
            // (0,5; 0,84305316; -1,0349569)
            // (-0,5; 0,15694684; -1,0349569)
        };
    }
};

const spheres = [_]Sphere{
    Sphere{ .position = Vec3(f32){ .x = 0, .y = 0.5, .z = 4 }, .radius = 1 },
};

const camera = Camera.init();

export fn init() void {
    const vertex = @embedFile("vertex.glsl");
    const fragment = @embedFile("fragment.glsl");

    const vertex_idx = gl.compileShader(vertex.ptr, vertex.len, gl.VERTEX_SHADER);

    const fragment_idx = gl.compileShader(fragment.ptr, fragment.len, gl.FRAGMENT_SHADER);

    const program = gl.createProgram(vertex_idx, fragment_idx);
    gl.useProgram(program);

    const pos = "a_Position";
    gl.createBufferAndBind(program, &vertices, vertices.len, vertices.len / vertices_count, pos.ptr, pos.len);

    const uv = "a_Uv";
    gl.createBufferAndBind(program, &uvs, uvs.len, uvs.len / vertices_count, uv.ptr, uv.len);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    // set uniforms
    gl.uniform(Vec3(f32), program, "camera.position", camera.position);
    gl.uniform(Vec3(f32), program, "camera.p0", camera.p0);
    gl.uniform(Vec3(f32), program, "camera.p1", camera.p1);
    gl.uniform(Vec3(f32), program, "camera.p2", camera.p2);

    gl.uniform(i32, program, "sphereCount", spheres.len);
    inline for (spheres, 0..) |sphere, i| {
        gl.uniform(Vec3(f32), program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".position", sphere.position);
        gl.uniform(f32, program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".radius", sphere.radius);
    }

    gl.drawArrays(vertices_count);
}
