const gl = @import("gl.zig");

const Self = @This();

active: Fbo,
other: Fbo,
program: usize,

pub fn init(width: usize, height: usize, texture_unit_one: gl.TextureUnit, texture_unit_two: gl.TextureUnit) Self {
    const active = createFbo(width, height, texture_unit_one);
    const other = createFbo(width, height, texture_unit_two);
    const program = createPostProcessShader();

    return .{
        .active = active,
        .other = other,
        .program = program,
    };
}

pub fn bind(self: Self) void {
    gl.bindFramebuffer(self.active.framebuffer);

    gl.activeTexture(self.active.texture_unit.num);
    gl.bindNullTexture();
}

pub fn draw_active_to_screen(self: Self) void {
    gl.bindNullFramebuffer();
    gl.useProgram(self.program);

    gl.activeTexture(self.active.texture_unit.num);
    gl.bindTexture(self.active.texture);
    gl.uniform(usize, self.program, "u_texture", self.active.texture_unit.toIndex());

    gl.drawArrays(3);
}

pub fn swap(self: *Self) void {
    const temp = self.active;
    self.active = self.other;
    self.other = temp;
}

const Fbo = struct {
    framebuffer: usize,
    texture: usize,
    texture_unit: gl.TextureUnit,
};

fn createFbo(width: usize, height: usize, texture_unit: gl.TextureUnit) Fbo {
    const framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(framebuffer);
    const texture = gl.createFramebufferTexture(width, height);

    return .{
        .framebuffer = framebuffer,
        .texture = texture,
        .texture_unit = texture_unit,
    };
}

fn createPostProcessShader() usize {
    const vertex =
        \\ #version 300 es
        \\ out vec2 v_texCoord;
        \\ void main() {
        \\   vec2 pos = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
        \\   v_texCoord = vec2(pos.x, pos.y);
        \\   gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
        \\ }
    ;
    const fragment =
        \\ #version 300 es
        \\ precision mediump float;
        \\
        \\ in vec2 v_texCoord;
        \\ uniform sampler2D u_texture;
        \\ out vec4 fragColor;
        \\
        \\ void main() {
        \\   fragColor = texture(u_texture, v_texCoord);
        \\ }
    ;

    const vertex_idx = gl.compileShader(vertex.ptr, vertex.len, gl.VERTEX_SHADER);
    const fragment_idx = gl.compileShader(fragment.ptr, fragment.len, gl.FRAGMENT_SHADER);

    return gl.createProgram(vertex_idx, fragment_idx);
}
