const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

//.x .y .z
pub fn Vec(comptime T: type, comptime taille_: usize) type {
    return struct {
        const Self = @This();
        const taille = taille_;

        pub const Component =
            if (taille_ == 2)
                enum { x, y }
            else if (taille_ == 3)
                enum { x, y, z }
            else if (taille_ == 4)
                enum { x, y, z, w };

        data: [taille_]T,

        pub fn new(data: @Vector(taille_, T)) Self {
            return .{ .data = data };
        }

        pub fn eql(self: Self, other: Self) bool {
            const a: @Vector(taille_, T) = self.data;
            const b: @Vector(taille_, T) = other.data;
            return @reduce(.And, a == b);
        }

        pub fn at(self: *Self, index: usize) *T {
            assert(index < taille_);
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
            const a: @Vector(taille_, T) = self.data;
            const b: @Vector(taille_, T) = other.data;
            return Self.new(a + b);
        }

        pub inline fn sub(self: Self, other: Self) Self {
            const a: @Vector(taille_, T) = self.data;
            const b: @Vector(taille_, T) = other.data;
            return Self.new(a - b);
        }

        pub fn mul(self: Self, other: Self) Self {
            const a: @Vector(taille_, T) = self.data;
            const b: @Vector(taille_, T) = other.data;
            return Self.new(a * b);
        }

        const componentMul = Self.mul;

        pub fn div(self: Self, other: Self) Self {
            const a: @Vector(taille_, T) = self.data;
            const b: @Vector(taille_, T) = other.data;
            return Self.new(a / b);
        }

        pub fn dot(self: Self, other: Self) T {
            return @reduce(.Add, self.data * other.data);
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

        pub fn length(self: Self) T {
            return @sqrt(self.dot());
        }

        pub fn length2(self: Self) T {
            return self.dot(self);
        }

        pub fn normalize(self: Self) Self {
            const len = self.length();
            assert(len != 0);
            var ret: Self = undefined;
            for (self.data, &ret.data) |a, *r| {
                r.* = a / len;
            }
            return ret;
        }
    };
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

pub fn Mat(T: type, taille_i_: usize, taille_j_: usize) type {
    return struct {
        const Self = @This();
        const taille_i = taille_i_;
        const taille_j = taille_j_;

        data: [taille_i]Vec(T, taille_j),

        //pub fn perspective(fovy: T, aspect: T, zNear: T, zFar: T) Self{
        //    if (taille_i != 4 or taille_j != 4) @compileError("perspective seulement pour matrices 4x4");
        //}

        //pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Self{
        //    if (taille_i != 4 or taille_j != 4) @compileError("lootAt seulement pour matrices 4x4");
        //}

        pub fn at(self: *Self, i: usize) *Vec(T, taille_j) {
            assert(i < taille_i);
            return &self.data[i];
        }

        pub fn eql(self: Self, other: Self) bool {
            for (self.data, other.data) |a, b| {
                if (!a.eql(b)) return false;
            }
            return true;
        }

        //pub fn new(args: anytype) Self {
        //    comptime if (@typeInfo(@TypeOf(args)) != .Struct) {
        //        @compileError("Mat.new attend un tuple de lignes");
        //    };
        //    if (args.len != taille_i)
        //        @compileError("Mauvais nombre de lignes");
        //    var ret: Self = undefined;
        //    inline for (args, 0..) |row_arg, i| {
        //        ret.data[i] = row_arg;
        //    }
        //    return ret;
        //}
        pub fn new(args: [taille_i]Vec(T, taille_j)) Self {
            var ret: Self = undefined;
            for (args, &ret.data) |src, *dest| {
                dest.* = src;
            }
            return ret;
        }

        pub fn row(self: Self, i: usize) Vec(T, taille_j) {
            assert(i < taille_i);
            return self.data[i];
        }

        pub fn col(self: Self, j: usize) Vec(T, taille_i) {
            assert(j < taille_j);
            var ret: Vec(T, taille_i) = undefined;
            for (0..taille_i) |i| {
                ret.at(i).* = self.data[i].at(j).*;
            }
            return ret;
        }

        pub fn add(self: Self, other: Self) Self {
            var ret: Self = undefined;
            for (self.data, other.data, &ret.data) |a, b, *dest| {
                dest.* = a.add(b);
            }
            return ret;
        }

        pub fn sub(self: Self, other: Self) Self {
            var ret: Self = undefined;
            for (self.data, other.data, &ret.data) |a, b, *dest| {
                dest.* = a.sub(b);
            }
            return ret;
        }

        pub fn componentMul(self: Self, other: Self) Self {
            var ret: Self = undefined;
            for (self.data, other.data, &ret.data) |a, b, *dest| {
                dest.* = a.componentMul(b);
            }
            return ret;
        }

        pub fn mul(self: Self, other: anytype) if (Self.taille_i == 1) Vec(T, Self.taille_j) else Mat(T, Self.taille_i, @TypeOf(other).taille_j) {
            const MatA = @TypeOf(self);
            const MatB = @TypeOf(other);
            if (MatA.taille_j != MatB.taille_i) @compileError("Les matrices ne sont pas multipliables");
            var ret: Mat(T, MatA.taille_i, MatB.taille_j) = undefined;
            for (0..MatA.taille_i, 0..MatB.taille_j) |i, j| {
                ret.at(i).at(j).* = self.row(i).dot(other.col(j));
            }
            return ret;
        }
    };
}

pub const Mat2 = Mat(f32, 2, 2);
pub const Mat2x3 = Mat(f32, 2, 3);
pub const Mat2x4 = Mat(f32, 2, 4);

pub const Mat3x2 = Mat(f32, 3, 2);
pub const Mat3 = Mat(f32, 3, 3);
pub const Mat3x4 = Mat(f32, 3, 4);

pub const Mat4x2 = Mat(f32, 4, 2);
pub const Mat4x3 = Mat(f32, 4, 3);
pub const Mat4 = Mat(f32, 4, 4);

pub fn mul(args: anytype) @typeInfo(@TypeOf(args)).@"struct".fields[0].type {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);
    if (args_type_info != .@"struct") {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
    }
    const fields = args_type_info.@"struct".fields;
    if (fields.len == 0) @compileError("tuple cannot be empty");
    if (fields.len == 1) return fields[0];

    const elements: [fields.len]fields[0].type = args;
    var resultat = elements[0];
    inline for (1..elements.len) |i| {
        resultat = resultat.mul(elements[i]);
    }
    return resultat;
}

test "taille vecteur" {
    inline for (0..16) |i| {
        try expect(@sizeOf(Vec(f32, i)) == @sizeOf([i]f32));
        try expect(@sizeOf(Vec(i32, i)) == @sizeOf([i]i32));
        try expect(@sizeOf(Vec(f64, i)) == @sizeOf([i]f64));
    }
}

test "multiplication de vecteur" {
    const resultat: Vec4 = mul(.{
        Vec4.new(.{ 1, 2, 3, -4 }),
        Vec4.new(.{ 0, 1, 2, -4 }),
        Vec4.new(.{ 3, 0.5, -1, 1 }),
    });
    try expect(resultat.eql(Vec4.new(.{ 0, 1, -6, 16 })));
}

test "matrice" {
    const a = Mat4.new(.{
        Vec4.new(.{ 1, 0, 0, 0 }),
        Vec4.new(.{ 0, 1, 0, 0 }),
        Vec4.new(.{ 0, 0, 1, 0 }),
        Vec4.new(.{ 0, 0, 0, 1 }),
    });

    const b = Mat4.new(.{
        Vec4.new(.{ 1, 0, 0, 0 }),
        Vec4.new(.{ 0, 1, 0, 0 }),
        Vec4.new(.{ 0, 0, 1, 0 }),
        Vec4.new(.{ 0, 0, 0, 1 }),
    });

    try expect(a.eql(b));
}
