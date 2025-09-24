const std = @import("std");

//.x .y .z
pub fn Vec(comptime type_: type, comptime taille_: usize) type {
    const ret = struct {
        const Self = @This();

        pub const Component =
            if (taille_ == 2)
                enum { x, y }
            else if (taille_ == 3)
                enum { x, y, z }
            else if (taille_ == 4)
                enum { x, y, z, w };

        data: @Vector(taille_, type_),

        pub fn at(self: *Self, index: usize) *type_ {
            std.debug.assert(index < taille_);
            return &self.data[index];
        }

        pub fn x(self: *Self) *f32 {
            if (taille_ < 1) @compileError("Pas de champ .x dans un Vec");
            return &self.data[0];
        }

        pub fn y(self: *Self) *f32 {
            if (taille_ < 2) @compileError("Pas de champ .y dans un Vec");
            return &self.data[1];
        }

        pub fn z(self: *Self) *f32 {
            if (taille_ < 3) @compileError("Pas de champ .z dans un Vec");
            return &self.data[2];
        }

        pub fn w(self: *Self) *f32 {
            if (taille_ < 4) @compileError("Pas de champ .w dans un Vec");
            return &self.data[3];
        }

        pub inline fn add(self: Self, other: Self) Self {
            return .{ .data = .{self.data + other.data} };
            //var ret: Self = undefined;
            //for (self.data, other.data, &ret.data) |a, b, *r| {
            //    r.* = a + b;
            //}
            //return ret;
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return .{ .data = .{self.data - other.data} };
            //var ret: Self = undefined;
            //for (self.data, other.data, &ret.data) |a, b, *r| {
            //    r.* = a - b;
            //}
            //return ret;
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .data = .{self.data * other.data} };
            //var ret: Self = undefined;
            //for (self.data, other.data, &ret.data) |a, b, *r| {
            //    r.* = a * b;
            //}
            //return ret;
        }

        pub fn div(self: Self, other: Self) Self {
            return .{ .data = .{self.data / other.data} };
            //var ret: Self = undefined;
            //for (self.data, other.data, &ret.data) |a, b, *r| {
            //    r.* = a / b;
            //}
            //return ret;
        }

        pub fn dot(self: Self, other: Self) type_ {
            return @reduce(.Add, self.data * other.data);
            //var ret: type_ = 0;
            //for (self.data, other.data) |a, b| {
            //    ret += a * b;
            //}
            //return ret;
        }

        pub fn cross(self: Self, other: Self) Self {
            if (taille_ != 3) @compileError("cross product seulement défini pour Vec3");
            return Self{
                .data = .{
                    self.data[1] * other.data[2] - self.data[2] * other.data[1],
                    self.data[2] * other.data[0] - self.data[0] * other.data[2],
                    self.data[0] * other.data[1] - self.data[1] * other.data[0],
                },
            };
        }

        pub fn length(self: Self) type_ {
            return @sqrt(self.dot());
        }

        pub fn length2(self: Self) type_ {
            return self.dot(self);
        }

        pub fn normalize(self: Self) Self {
            const len = self.length();
            std.debug.assert(len != 0);
            var ret: Self = undefined;
            for (self.data, &ret.data) |a, *r| {
                r.* = a / len;
            }
            return ret;
        }
    };
    return ret;
}

pub const Vec2 = Vec(f32, 2);
pub const Vec3 = Vec(f32, 3);
pub const Vec4 = Vec(f32, 4);

pub const Dvec2 = Vec(f64, 2);
pub const Dvec3 = Vec(f64, 3);
pub const Dvec4 = Vec(f64, 4);

pub const Ivec2 = Vec(i32, 2);
pub const Ivec3 = Vec(i32, 3);
pub const Ivec4 = Vec(i32, 4);

pub const Uvec2 = Vec(u32, 2);
pub const Uvec3 = Vec(u32, 3);
pub const Uvec4 = Vec(u32, 4);

pub fn Mat(type_: type, taille_i: usize, taille_j: usize) type {
    return struct {
        const Self = @This();

        data: [taille_i]Vec(taille_j, type_),

        //pub fn perspective(fovy: type_, aspect: type_, zNear: type_, zFar: type_) Self{
        //    if (taille_i != 4 or taille_j != 4) @compileError("perspective seulement pour matrices 4x4");
        //}

        //pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Self{
        //    if (taille_i != 4 or taille_j != 4) @compileError("lootAt seulement pour matrices 4x4");
        //}
    };
}
