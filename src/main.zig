const std = @import("std");
const print = @import("utils.zig").print;
const gl = @import("gl.zig");
const math = @import("math.zig");
const PingPongBuffer = @import("PingPongBuffer.zig");

const Vec3 = math.Vec3;
const Color = Vec3;

const Sphere = struct {
    position: Vec3,
    radius: f32,
    texture: Texture,
};

const Floor = struct {
    position: Vec3,
    texture_size: f32,
    texture: Texture,
};

const Camera = struct {
    position: Vec3,
    direction: Vec3,
    yaw: f32,
    pitch: f32,
    fov: f32,

    fn init(fov: f32) Camera {
        var c = Camera{
            .position = Vec3{ .x = 0, .y = 0.5, .z = -2 },
            .direction = Vec3{ .x = 0, .y = 0, .z = 1 },
            .yaw = 90.0,
            .pitch = 0.0,
            .fov = fov,
        };
        c.updateDirection();
        return c;
    }

    fn forward(self: Camera) Vec3 {
        return (Vec3{ .x = self.direction.x, .y = 0, .z = self.direction.z }).normalized();
    }

    fn left(self: Camera) Vec3 {
        return self.forward().cross(.{ .x = 0, .y = 1, .z = 0 }).normalized();
    }

    fn updateDirection(self: *Camera) void {
        const rad_yaw = std.math.degreesToRadians(self.yaw);
        const rad_pitch = std.math.degreesToRadians(self.pitch);

        self.direction = (Vec3{
            .x = @cos(rad_pitch) * @cos(rad_yaw),
            .y = @sin(rad_pitch),
            .z = @cos(rad_pitch) * @sin(rad_yaw),
        }).normalized();
    }

    fn addYaw(self: *Camera, degrees: f32) void {
        self.yaw += degrees;
        self.updateDirection();
    }

    fn addPitch(self: *Camera, degrees: f32) void {
        self.pitch += degrees;

        if (self.pitch > 89.0) self.pitch = 89.0;
        if (self.pitch < -89.0) self.pitch = -89.0;

        self.updateDirection();
    }
};

const Texture = struct {
    albedo: Vec3,
    specular: f32,
    shininess: i32,
    reflectivity: f32,
    roughness: f32,
    has_image: bool,
    texture_unit: i32,

    fn diffuse(color: Color) Texture {
        return .{
            .albedo = color,
            .specular = 0,
            .shininess = 1,
            .reflectivity = 0,
            .roughness = 0,
            .has_image = false,
            .texture_unit = -1,
        };
    }

    fn reflective(color: Color, reflectivity: f32, roughness: f32) Texture {
        return .{
            .albedo = color,
            .specular = 0,
            .shininess = 1,
            .reflectivity = reflectivity,
            .roughness = roughness,
            .has_image = false,
            .texture_unit = -1,
        };
    }

    fn mirror(color: Color) Texture {
        return .{
            .albedo = color,
            .specular = 0,
            .shininess = 1,
            .reflectivity = 1,
            .roughness = 0,
            .has_image = false,
            .texture_unit = -1,
        };
    }

    fn addImage(self: Texture, image_src: []const u8) Texture {
        const index = gl.bindAndCreateTexture(image_src.ptr, image_src.len);

        var new = self;
        new.has_image = true;
        new.texture_unit = @intCast(index);
        return new;
    }
};

const Light = struct {
    position: Vec3,
    color: Color,
    intensity: f32,
};

const Sky = struct {
    texture: Texture,
    color: Color,

    fn init(color: Color, image_src: []const u8) Sky {
        return .{ .color = color, .texture = Texture.diffuse(color).addImage(image_src) };
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

const maxRecursionDepth = 5;

const spheres = [_]Sphere{
    Sphere{ .position = Vec3{ .x = 0, .y = 0.5, .z = 0 }, .radius = 0.5, .texture = Texture.diffuse(Color.init(1, 0, 0)) },
    Sphere{ .position = Vec3{ .x = -2, .y = 0.5, .z = 1 }, .radius = 0.5, .texture = Texture.mirror(Color.white()) },
    Sphere{ .position = Vec3{ .x = -3, .y = 0.5, .z = -1 }, .radius = 0.5, .texture = Texture.mirror(Color.white()) },
    Sphere{ .position = Vec3{ .x = 2, .y = 0.5, .z = 1 }, .radius = 0.5, .texture = Texture.reflective(Color.init(0, 1, 0), 1, 0.2) },
};
const lights = [_]Light{
    Light{ .position = Vec3{ .x = 0.5, .y = 2, .z = 0 }, .color = Vec3.white(), .intensity = 1 },
};
var floor: Floor = undefined;

const ambient_intensity = 1;

var camera = Camera.init(90);

var program: usize = 0;

var sky: Sky = undefined;

var prng = std.Random.DefaultPrng.init(0);
const rand = prng.random();

var ping_pong_buffer: PingPongBuffer = undefined;

export fn init(width: usize, height: usize) void {
    ping_pong_buffer = .init(width, height, gl.TEXTURE0, gl.TEXTURE1);

    sky = Sky.init(Vec3.init(0.1, 0.1, 0.1), "dikhololo_night_2k.png");
    floor = Floor{
        .position = Vec3{ .x = 0, .y = 0, .z = 0 },
        .texture_size = 1,
        .texture = Texture.reflective(Color.white(), 1, 0.5).addImage("ground.png"),
    };

    const vertex = @embedFile("vertex.glsl");
    const fragment = @embedFile("fragment.glsl");

    const vertex_idx = gl.compileShader(vertex.ptr, vertex.len, gl.VERTEX_SHADER);

    const fragment_idx = gl.compileShader(fragment.ptr, fragment.len, gl.FRAGMENT_SHADER);

    program = gl.createProgram(vertex_idx, fragment_idx);
}

var num_of_samples: usize = 0;
export fn tick(width: usize, height: usize) void {
    // draw the scene to the framebuffer
    ping_pong_buffer.bind();

    const changed = handleKeyState();
    if (changed) {
        num_of_samples = 0;
    }

    gl.useProgram(program);

    var t_idx: usize = 0;
    const texture_index: *usize = &t_idx;

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    // set uniforms
    gl.uniform(usize, program, "previousFrame", ping_pong_buffer.other.texture_unit - gl.TEXTURE0);
    gl.uniform(usize, program, "numOfSamples", num_of_samples);
    num_of_samples += 1;

    gl.uniform(f32, program, "seed", rand.float(f32));
    gl.uniform(usize, program, "maxRecursionDepth", maxRecursionDepth);
    gl.uniform(usize, program, "width", width);
    gl.uniform(usize, program, "heigth", height);

    gl.uniform(Vec3, program, "camera.position", camera.position);
    gl.uniform(Vec3, program, "camera.direction", camera.direction);
    gl.uniform(f32, program, "camera.fov", camera.fov);

    gl.uniform(bool, program, "shadeFloor", true);
    gl.uniform(Vec3, program, "floorPlane.position", floor.position);
    gl.uniform(f32, program, "floorPlane.textureSize", floor.texture_size);
    setTextureUniform("floorPlane", floor.texture, texture_index);

    gl.uniform(usize, program, "sphereCount", spheres.len);
    inline for (spheres, 0..) |sphere, i| {
        gl.uniform(Vec3, program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".position", sphere.position);
        gl.uniform(f32, program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".radius", sphere.radius);

        setTextureUniform(std.fmt.comptimePrint("sphere[{d}]", .{i}), sphere.texture, texture_index);
    }

    gl.uniform(usize, program, "lightCount", lights.len);
    inline for (lights, 0..) |light, i| {
        gl.uniform(Vec3, program, std.fmt.comptimePrint("light[{d}]", .{i}) ++ ".position", light.position);
        gl.uniform(Vec3, program, std.fmt.comptimePrint("light[{d}]", .{i}) ++ ".color", light.color);
        gl.uniform(f32, program, std.fmt.comptimePrint("light[{d}]", .{i}) ++ ".intensity", light.intensity);
    }

    gl.uniform(Vec3, program, "sky.color", sky.color);
    setTextureUniform("sky", sky.texture, texture_index);

    gl.uniform(f32, program, "ambientIntensity", ambient_intensity);

    gl.drawArrays(3);

    // draw the framebuffer to the canvas
    ping_pong_buffer.draw_active_to_screen();

    ping_pong_buffer.swap();
}

fn setTextureUniform(comptime base_name: []const u8, texture: Texture, texture_index: *usize) void {
    const name = base_name ++ ".texture";

    gl.uniform(Vec3, program, name ++ ".albedo", texture.albedo);
    gl.uniform(f32, program, name ++ ".specular", texture.specular);
    gl.uniform(i32, program, name ++ ".shininess", texture.shininess);
    gl.uniform(f32, program, name ++ ".reflectivity", texture.reflectivity);
    gl.uniform(f32, program, name ++ ".roughness", texture.roughness);
    gl.uniform(bool, program, name ++ ".hasImage", texture.has_image);
    gl.uniform(usize, program, name ++ ".textureIndex", texture_index.*);

    if (texture.has_image) {
        var buf: [32]u8 = undefined;
        const tex_name = std.fmt.bufPrint(&buf, "textures[{d}]", .{texture_index.*}) catch unreachable;
        texture_index.* += 1;

        gl.uniform(i32, program, tex_name, texture.texture_unit);
    }
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

export fn onMouseMove(delta_x: f32, delta_y: f32) void {
    const sens = 0.1;
    camera.addYaw(-delta_x * sens);
    camera.addPitch(-delta_y * sens);
    num_of_samples = 0;
}

fn handleKeyState() bool {
    const speed = 0.05;

    var changes = false;

    const f = camera.forward();
    const l = camera.left();
    if (keyState.forwards) {
        camera.position.add(f.mult(speed));
        changes = true;
    }
    if (keyState.backwards) {
        camera.position.add(f.mult(-speed));
        changes = true;
    }
    if (keyState.right) {
        camera.position.add(l.mult(-speed));
        changes = true;
    }
    if (keyState.left) {
        camera.position.add(l.mult(speed));
        changes = true;
    }
    if (keyState.up) {
        camera.position.add(.{ .x = 0, .y = speed, .z = 0 });
        changes = true;
    }
    if (keyState.down) {
        camera.position.add(.{ .x = 0, .y = -speed, .z = 0 });
        if (camera.position.y < 0) {
            camera.position.y = 0;
        }
        changes = true;
    }
    return changes;
}
