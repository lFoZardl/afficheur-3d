const std = @import("std");

//.x .y .z
pub fn Vec(taille_: usize, type_: type) type {
    return struct {
        const Self = @This();

        data: [taille_]type_,

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

        pub fn add(self: Self, other: Self) Self {
            var ret: Self = undefined;
            for (self.data, other.data, &ret.data) |a, b, *r| {
                r.* = a + b;
            }
            return ret;
        }

        pub fn sub(self: Self, other: Self) Self {
            var ret: Self = undefined;
            for (self.data, other.data, &ret.data) |a, b, *r| {
                r.* = a - b;
            }
            return ret;
        }

        pub fn mul(self: Self, other: Self) Self {
            var ret: Self = undefined;
            for (self.data, other.data, &ret.data) |a, b, *r| {
                r.* = a * b;
            }
            return ret;
        }

        pub fn div(self: Self, other: Self) Self {
            var ret: Self = undefined;
            for (self.data, other.data, &ret.data) |a, b, *r| {
                r.* = a / b;
            }
            return ret;
        }

        pub fn dot(self: Self, other: Self) type_ {
            var ret: type_ = 0;
            for (self.data, other.data) |a, b| {
                ret += a * b;
            }
            return ret;
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
}

export const Vec2 = Vec(2, f32);
export const Vec3 = Vec(3, f32);
export const Vec4 = Vec(4, f32);

export const Dvec2 = Vec(2, f64);
export const Dvec3 = Vec(3, f64);
export const Dvec4 = Vec(4, f64);

export const Ivec2 = Vec(2, i32);
export const Ivec3 = Vec(3, i32);
export const Ivec4 = Vec(4, i32);

export const Uvec2 = Vec(2, u32);
export const Uvec3 = Vec(3, u32);
export const Uvec4 = Vec(4, u32);

pub fn Mat(taille_i: usize, taille_j: usize, type_: type) type {
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
