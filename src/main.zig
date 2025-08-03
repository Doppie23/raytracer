const std = @import("std");
const print = @import("utils.zig").print;
const gl = @import("gl.zig");
const math = @import("math.zig");
const PingPongBuffer = @import("PingPongBuffer.zig");
const ResourceManager = @import("ResourceManager.zig");

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
    shininess: u32,
    reflectivity: f32,
    roughness: f32,
    has_image: bool,
    texture_unit: ?gl.TextureUnit,

    fn diffuse(color: Color) Texture {
        return .{
            .albedo = color,
            .specular = 0,
            .shininess = 1,
            .reflectivity = 0,
            .roughness = 0,
            .has_image = false,
            .texture_unit = null,
        };
    }

    fn shiny(color: Color, specular: f32, shininess: u32) Texture {
        return .{
            .albedo = color,
            .specular = specular,
            .shininess = shininess,
            .reflectivity = 0,
            .roughness = 0,
            .has_image = false,
            .texture_unit = null,
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
            .texture_unit = null,
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
            .texture_unit = null,
        };
    }

    fn addImage(self: *Texture, texture_unit: gl.TextureUnit) void {
        self.has_image = true;
        self.texture_unit = texture_unit;
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

    fn init(color: Color) Sky {
        return .{ .color = color, .texture = Texture.diffuse(color) };
    }
};

const maxRecursionDepth = 5;

var key_state = KeyState.init();

var sky = Sky.init(Color.init(0.16, 0.11, 0.07));

const spheres = [_]Sphere{
    Sphere{ .position = Vec3{ .x = 0, .y = 0.5, .z = 0 }, .radius = 0.5, .texture = Texture.shiny(Color.init(1, 0, 0), 0.8, 256) },
    Sphere{ .position = Vec3{ .x = -0.6, .y = 0.2, .z = -0.2 }, .radius = 0.2, .texture = Texture.diffuse(Color.init(0, 0.2, 1)) },
    Sphere{ .position = Vec3{ .x = -2, .y = 0.5, .z = 1 }, .radius = 0.5, .texture = Texture.mirror(Color.white()) },
    Sphere{ .position = Vec3{ .x = -2.8, .y = 0.4, .z = 0.5 }, .radius = 0.4, .texture = Texture.shiny(Color.init(0.5, 1, 0.7), 0.7, 256) },
    Sphere{ .position = Vec3{ .x = -3, .y = 0.5, .z = -1 }, .radius = 0.5, .texture = Texture.mirror(Color.white()) },
    Sphere{ .position = Vec3{ .x = -2.5, .y = 0.1, .z = -0.3 }, .radius = 0.1, .texture = Texture.diffuse(Color.init(1, 1, 0.2)) },
    Sphere{ .position = Vec3{ .x = 2, .y = 0.5, .z = 1 }, .radius = 0.5, .texture = Texture.reflective(Color.init(0, 1, 0), 1, 0.2) },
    Sphere{ .position = Vec3{ .x = 2.4, .y = 0.5, .z = 0 }, .radius = 0.5, .texture = Texture.mirror(Color.white()) },
    Sphere{ .position = Vec3{ .x = 1.2, .y = 0.3, .z = -0.7 }, .radius = 0.3, .texture = Texture.reflective(Color.init(1, 0.8, 0), 1, 0.2) },
};

const lights = [_]Light{
    Light{ .position = Vec3{ .x = 0, .y = 4, .z = -1 }, .color = Vec3.white(), .intensity = 1 },
    Light{ .position = Vec3{ .x = 1.5, .y = 1, .z = 1 }, .color = Vec3.white(), .intensity = 2 },
    Light{ .position = Vec3{ .x = -1, .y = 3, .z = 2 }, .color = Vec3.white(), .intensity = 7 },
    Light{ .position = Vec3{ .x = -4, .y = 4, .z = 2.5 }, .color = Vec3.white(), .intensity = 4 },
};

var floor = Floor{
    .position = Vec3{ .x = 0, .y = 0, .z = 0 },
    .texture_size = 1,
    .texture = Texture.reflective(Color.white(), 1, 0.4),
};

const ambient_intensity = 0.8;

const default_fov = 90;
var camera = Camera.init(default_fov);

var program: usize = 0;

var num_of_samples: u32 = 0;

var prng = std.Random.DefaultPrng.init(0);
const rand = prng.random();

var ping_pong_buffer: PingPongBuffer = undefined;

var resource_manager: ResourceManager = undefined;

export fn init(width: usize, height: usize) void {
    ping_pong_buffer = .init(width, height, gl.TEXTURE0, gl.TEXTURE1);
    resource_manager = .init(gl.TEXTURE2);

    const sky_img = resource_manager.create_texture("assets/dikhololo_night_2k.png");
    const ground_img = resource_manager.create_texture("assets/ground.png");

    sky.texture.addImage(sky_img);
    floor.texture.addImage(ground_img);

    const vertex = @embedFile("shaders/vertex.glsl");
    const fragment = @embedFile("shaders/fragment.glsl");

    const vertex_idx = gl.compileShader(vertex.ptr, vertex.len, gl.VERTEX_SHADER);
    const fragment_idx = gl.compileShader(fragment.ptr, fragment.len, gl.FRAGMENT_SHADER);

    program = gl.createProgram(vertex_idx, fragment_idx);
}

export fn tick(width: u32, height: u32) void {
    // draw the scene to the framebuffer
    ping_pong_buffer.bind();

    defer num_of_samples += 1;

    const changed = handleKeyState();
    if (changed) {
        num_of_samples = 0;
    }

    gl.useProgram(program);

    var t_idx: u32 = 0;
    const texture_array_index: *u32 = &t_idx;

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    // set uniforms
    gl.uniform(i32, program, "previousFrame", ping_pong_buffer.other.texture_unit.toIndex());
    gl.uniform(u32, program, "numOfSamples", num_of_samples);

    gl.uniform(f32, program, "seed", rand.float(f32));
    gl.uniform(u32, program, "maxRecursionDepth", maxRecursionDepth);
    gl.uniform(u32, program, "width", width);
    gl.uniform(u32, program, "heigth", height);

    gl.uniform(Vec3, program, "camera.position", camera.position);
    gl.uniform(Vec3, program, "camera.direction", camera.direction);
    gl.uniform(f32, program, "camera.fov", camera.fov);

    gl.uniform(bool, program, "shadeFloor", true);
    gl.uniform(Vec3, program, "floorPlane.position", floor.position);
    gl.uniform(f32, program, "floorPlane.textureSize", floor.texture_size);
    setTextureUniform("floorPlane", floor.texture, texture_array_index);

    gl.uniform(u32, program, "sphereCount", spheres.len);
    inline for (spheres, 0..) |sphere, i| {
        gl.uniform(Vec3, program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".position", sphere.position);
        gl.uniform(f32, program, std.fmt.comptimePrint("sphere[{d}]", .{i}) ++ ".radius", sphere.radius);

        setTextureUniform(std.fmt.comptimePrint("sphere[{d}]", .{i}), sphere.texture, texture_array_index);
    }

    gl.uniform(u32, program, "lightCount", lights.len);
    inline for (lights, 0..) |light, i| {
        gl.uniform(Vec3, program, std.fmt.comptimePrint("light[{d}]", .{i}) ++ ".position", light.position);
        gl.uniform(Vec3, program, std.fmt.comptimePrint("light[{d}]", .{i}) ++ ".color", light.color);
        gl.uniform(f32, program, std.fmt.comptimePrint("light[{d}]", .{i}) ++ ".intensity", light.intensity);
    }

    gl.uniform(Vec3, program, "sky.color", sky.color);
    setTextureUniform("sky", sky.texture, texture_array_index);

    gl.uniform(f32, program, "ambientIntensity", ambient_intensity);

    gl.drawArrays(3);

    // draw the framebuffer to the canvas
    ping_pong_buffer.draw_active_to_screen();

    ping_pong_buffer.swap();
}

fn setTextureUniform(comptime base_name: []const u8, texture: Texture, texture_array_index: *u32) void {
    const name = base_name ++ ".texture";

    gl.uniform(Vec3, program, name ++ ".albedo", texture.albedo);
    gl.uniform(f32, program, name ++ ".specular", texture.specular);
    gl.uniform(u32, program, name ++ ".shininess", texture.shininess);
    gl.uniform(f32, program, name ++ ".reflectivity", texture.reflectivity);
    gl.uniform(f32, program, name ++ ".roughness", texture.roughness);
    gl.uniform(bool, program, name ++ ".hasImage", texture.has_image);
    gl.uniform(u32, program, name ++ ".textureIndex", texture_array_index.*);

    if (texture.has_image) {
        var buf: [32]u8 = undefined;
        const tex_name = std.fmt.bufPrint(&buf, "textures[{d}]", .{texture_array_index.*}) catch unreachable;
        texture_array_index.* += 1;

        gl.uniform(i32, program, tex_name, texture.texture_unit.?.toIndex());
    }
}

export fn onResize(width: u32, height: u32) void {
    num_of_samples = 0;
    ping_pong_buffer.resize(width, height);
}

const KeyState = struct {
    forwards: bool,
    backwards: bool,
    left: bool,
    right: bool,
    up: bool,
    down: bool,
    increase_fov: bool,
    decrease_fov: bool,
    reset_fov: bool,

    fn init() KeyState {
        return .{
            .forwards = false,
            .backwards = false,
            .left = false,
            .right = false,
            .up = false,
            .down = false,
            .increase_fov = false,
            .decrease_fov = false,
            .reset_fov = false,
        };
    }
};

export fn onKeyDown(key_code: usize, down: bool) void {
    // see keymap in js for key codes
    switch (key_code) {
        0 => key_state.forwards = down,
        1 => key_state.left = down,
        2 => key_state.backwards = down,
        3 => key_state.right = down,
        4 => key_state.up = down,
        5 => key_state.down = down,
        6 => key_state.decrease_fov = down,
        7 => key_state.increase_fov = down,
        8 => key_state.reset_fov = down,
        else => {},
    }
}

export fn moveCamera(forward: f32, right: f32, up: f32) void {
    const f = camera.forward();
    const l = camera.left();
    camera.position.add(f.mult(forward));
    camera.position.add(l.mult(-right));
    camera.position.add(.{ .x = 0, .y = up, .z = 0 });
    num_of_samples = 0;
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
    if (key_state.forwards) {
        camera.position.add(f.mult(speed));
        changes = true;
    }
    if (key_state.backwards) {
        camera.position.add(f.mult(-speed));
        changes = true;
    }
    if (key_state.right) {
        camera.position.add(l.mult(-speed));
        changes = true;
    }
    if (key_state.left) {
        camera.position.add(l.mult(speed));
        changes = true;
    }
    if (key_state.up) {
        camera.position.add(.{ .x = 0, .y = speed, .z = 0 });
        changes = true;
    }
    if (key_state.down) {
        camera.position.add(.{ .x = 0, .y = -speed, .z = 0 });
        if (camera.position.y < 0.1) {
            camera.position.y = 0.1;
        }
        changes = true;
    }
    if (key_state.increase_fov) {
        camera.fov -= 1;
        if (camera.fov < 1) {
            camera.fov = 1;
        }
        changes = true;
    }
    if (key_state.decrease_fov) {
        camera.fov += 1;
        if (camera.fov > 160) {
            camera.fov = 160;
        }
        changes = true;
    }
    if (key_state.reset_fov) {
        camera.fov = default_fov;
        changes = true;
    }
    return changes;
}
