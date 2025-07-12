const Vec3 = @import("math.zig").Vec3;

pub const COLOR_BUFFER_BIT = 16384;
pub const VERTEX_SHADER = 35633;
pub const FRAGMENT_SHADER = 35632;

pub const TEXTURE0 = 33984;
pub const TEXTURE1 = 33985;

pub extern fn compileShader(ptr: [*]const u8, len: usize, shaderType: usize) usize;
pub extern fn createProgram(vertexShaderIdx: usize, fragmentShaderIdx: usize) usize;
pub extern fn useProgram(programIdx: usize) void;
pub extern fn createBufferAndBind(programIdx: usize, dataPtr: [*]const f32, dataLen: usize, dataSize: usize, attPtr: [*]const u8, attLen: usize) void;
pub extern fn drawArrays(count: usize) void;
pub extern fn clearColor(r: f32, g: f32, b: f32, a: f32) void;
pub extern fn clear(color: usize) void;
pub extern fn bindAndCreateTexture(srcPtr: [*]const u8, srcLen: usize) i32;
pub extern fn createFramebuffer() usize;
pub extern fn bindFramebuffer(framebufferIdx: usize) void;
pub extern fn activeTexture(textureUnit: usize) void;
pub extern fn createTexture() usize;
pub extern fn bindTexture(textureIdx: usize) void;
pub extern fn bindNullTexture() void;
pub extern fn createFramebufferTexture(width: i32, heigth: i32) usize;
pub extern fn bindNullFramebuffer() void;

extern fn uniform3f(programIdx: usize, uniformPtr: [*]const u8, uniformLen: usize, x: f32, y: f32, z: f32) void;
extern fn uniform1f(programIdx: usize, uniformPtr: [*]const u8, uniformLen: usize, x: f32) void;
extern fn uniform1i(programIdx: usize, uniformPtr: [*]const u8, uniformLen: usize, x: i32) void;

pub fn uniform(comptime T: type, programIdx: usize, name: []const u8, value: T) void {
    if (T == Vec3) {
        return uniform3f(programIdx, name.ptr, name.len, value.x, value.y, value.z);
    }
    if (T == f32) {
        return uniform1f(programIdx, name.ptr, name.len, value);
    }
    if (T == i32) {
        return uniform1i(programIdx, name.ptr, name.len, value);
    }
    if (T == bool) {
        return uniform1i(programIdx, name.ptr, name.len, if (value) 1 else 0);
    }

    @compileError("Unsupported uniform type");
}
