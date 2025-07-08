const std = @import("std");
const print = @import("utils.zig").print;
const gl = @import("gl.zig");
const math = @import("math.zig");

const Vec3 = math.Vec3;

const Sphere = struct {
    position: Vec3(f32),
    radius: f32,
};

const Camera = struct {
    position: Vec3(f32),
    direction: Vec3(f32),
    fov: f32,

    fn init(fov: f32) Camera {
        return .{
            .position = Vec3(f32){ .x = 0, .y = 0, .z = -2 },
            .direction = Vec3(f32){ .x = 0, .y = 0, .z = 1 },
            .fov = fov,
        };
    }

    /// returns the direction vector normalized
    fn getDirection(self: Camera) Vec3(f32) {
        return self.direction.normalized();
    }
};

const KeyState = struct {
    forwards: bool,
    backwards: bool,
    left: bool,
    right: bool,
    up: bool,
    down: bool,
};

var keyState: KeyState = .{
    .forwards = false,
    .backwards = false,
    .left = false,
    .right = false,
    .up = false,
    .down = false,
};

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

const spheres = [_]Sphere{
    Sphere{ .position = Vec3(f32){ .x = 0, .y = 0.5, .z = 0 }, .radius = 1 },
};

var camera = Camera.init(90);

var program: usize = 0;

export fn init() void {
    const vertex = @embedFile("vertex.glsl");
    const fragment = @embedFile("fragment.glsl");

    const vertex_idx = gl.compileShader(vertex.ptr, vertex.len, gl.VERTEX_SHADER);

    const fragment_idx = gl.compileShader(fragment.ptr, fragment.len, gl.FRAGMENT_SHADER);

    program = gl.createProgram(vertex_idx, fragment_idx);
    gl.useProgram(program);

    const pos = "a_Position";
    gl.createBufferAndBind(program, &vertices, vertices.len, vertices.len / vertices_count, pos.ptr, pos.len);

    const uv = "a_Uv";
    gl.createBufferAndBind(program, &uvs, uvs.len, uvs.len / vertices_count, uv.ptr, uv.len);
}

export fn tick(width: i32, height: i32) void {
    handleKeyState();

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    // set uniforms
    gl.uniform(i32, program, "width", width);
    gl.uniform(i32, program, "heigth", height);

    gl.uniform(Vec3(f32), program, "camera.position", camera.position);
    gl.uniform(Vec3(f32), program, "camera.direction", camera.getDirection());
    gl.uniform(f32, program, "camera.fov", camera.fov);

    gl.uniform(i32, program, "sphereCount", spheres.len);
    inline for (spheres, 0..) |sphere, i| {
        gl.uniform(Vec3(f32), program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".position", sphere.position);
        gl.uniform(f32, program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".radius", sphere.radius);
    }

    gl.drawArrays(vertices_count);
}

export fn onKeyDown(key_code: usize, down: bool) void {
    // see keymap in js for key codes
    switch (key_code) {
        0 => keyState.forwards = down,
        1 => keyState.left = down,
        2 => keyState.backwards = down,
        3 => keyState.right = down,
        4 => keyState.up = down,
        5 => keyState.down = down,
        else => {},
    }
}

fn handleKeyState() void {
    const speed = 0.05;

    if (keyState.forwards) {
        camera.position.add(.{ .x = 0, .y = 0, .z = speed });
    }
    if (keyState.backwards) {
        camera.position.add(.{ .x = 0, .y = 0, .z = -speed });
    }
    if (keyState.right) {
        camera.position.add(.{ .x = speed, .y = 0, .z = 0 });
    }
    if (keyState.left) {
        camera.position.add(.{ .x = -speed, .y = 0, .z = 0 });
    }
    if (keyState.up) {
        camera.position.add(.{ .x = 0, .y = speed, .z = 0 });
    }
    if (keyState.down) {
        camera.position.add(.{ .x = 0, .y = -speed, .z = 0 });
    }
}
