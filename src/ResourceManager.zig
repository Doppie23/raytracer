const gl = @import("gl.zig");

const Self = @This();

current_unit: gl.TextureUnit,

pub fn init(start_unit: gl.TextureUnit) Self {
    return .{
        .current_unit = start_unit,
    };
}

pub fn create_texture(self: *Self, comptime src: []const u8) gl.TextureUnit {
    gl.bindAndCreateTexture(src.ptr, src.len, self.current_unit.num);
    defer self.current_unit.num += 1;
    return self.current_unit;
}
