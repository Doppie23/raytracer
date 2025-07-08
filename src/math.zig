pub fn Vec3(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Vec3(T) {
            return .{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn white() Vec3(f32) {
            return Vec3(f32).init(1, 1, 1);
        }

        pub fn add(self: *Vec3(T), other: Vec3(T)) void {
            self.x += other.x;
            self.y += other.y;
            self.z += other.z;
        }

        pub fn length(self: Vec3(T)) f32 {
            return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        }

        pub fn normalized(self: Vec3(T)) Vec3(T) {
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

        pub fn cross(a: Vec3(T), b: Vec3(T)) Vec3(T) {
            return .{
                .x = a.y * b.z - a.z * b.y,
                .y = a.z * b.x - a.x * b.z,
                .z = a.x * b.y - a.y * b.x,
            };
        }

        pub fn mult(self: Vec3(T), n: T) Vec3(T) {
            return .{
                .x = self.x * n,
                .y = self.y * n,
                .z = self.z * n,
            };
        }
    };
}
