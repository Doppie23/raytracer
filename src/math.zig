pub const Vec3 = struct {
    const Self = @This();

    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Self {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn white() Self {
        return Self.init(1, 1, 1);
    }

    pub fn add(self: *Self, other: Self) void {
        self.x += other.x;
        self.y += other.y;
        self.z += other.z;
    }

    pub fn length(self: Self) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalized(self: Self) Self {
        const len = self.length();
        if (@abs(1 - len) < 0.001) {
            return self;
        }

        return .{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
        };
    }

    pub fn cross(a: Self, b: Self) Self {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn mult(self: Self, n: f32) Self {
        return .{
            .x = self.x * n,
            .y = self.y * n,
            .z = self.z * n,
        };
    }
};
