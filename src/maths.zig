const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

//.x .y .z
pub fn Vec(comptime type_: type, comptime taille_: usize) type {
    return struct {
        const Self = @This();
        pub const T = type_;
        pub const taille = taille_;
        pub const dimensions: usize = 1;

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

        pub const Iterator = struct {
            vec: *const Self,
            index: usize = 0,
            pub fn next(iter: *@This()) ?T {
                const ret = iter.peek();
                if (ret != null)
                    iter.index += 1;
                return ret;
            }
            pub fn peek(iter: *const @This()) ?T {
                return if (iter.index < iter.vec.data.len)
                    iter.vec.data[iter.index]
                else
                    null;
            }
            pub fn reset(iter: *@This()) void {
                iter.index = 0;
            }
        };

        pub fn begin(self: *const Self) Iterator {
            return Iterator{ .vec = self, .index = 0 };
        }

        pub fn at(self: *const Self, index: usize) *const T {
            assert(index < taille_);
            return &self.data[index];
        }

        pub fn x(self: *const Self) *const f32 {
            if (taille_ < 1) @compileError("Pas de champ .x dans un Vec");
            return &self.data[0];
        }

        pub fn y(self: *const Self) *const f32 {
            if (taille_ < 2) @compileError("Pas de champ .y dans un Vec");
            return &self.data[1];
        }

        pub fn z(self: *const Self) *const f32 {
            if (taille_ < 3) @compileError("Pas de champ .z dans un Vec");
            return &self.data[2];
        }

        pub fn w(self: *const Self) *const f32 {
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
            const a: @Vector(taille_, T) = self.data;
            const b: @Vector(taille_, T) = other.data;
            return @reduce(.Add, a * b);
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

        pub fn format(self: Self, writer: *std.Io.Writer) !void {
            //try writer.print("[", .{});
            //inline for (self.data, 0..) |n, i| {
            //    try writer.print("{}", .{n});
            //    if (self.data.len - 1 != i)
            //        try writer.print(",\t", .{});
            //}
            //try writer.print("]", .{});

            inline for (0..Self.taille) |j| { //col
                try writer.print("|{}|", .{self.data[j]});
                if (j != Self.taille - 1)
                    try writer.print("\n", .{});
            }
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

pub fn Mat(comptime type_: type, comptime taille_i_: usize, comptime taille_j_: usize) type {
    if (taille_i_ == 1) return Vec(type_, taille_j_);
    return struct {
        const Self = @This();
        pub const T = type_;
        pub const taille_i = taille_i_;
        pub const taille_j = taille_j_;
        pub const dimensions: usize = 2;

        data: [taille_i]Vec(T, taille_j),

        //pub fn perspective(fovy: T, aspect: T, zNear: T, zFar: T) Self{
        //    if (taille_i != 4 or taille_j != 4) @compileError("perspective seulement pour matrices 4x4");
        //}

        //pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Self{
        //    if (taille_i != 4 or taille_j != 4) @compileError("lootAt seulement pour matrices 4x4");
        //}

        pub const Iterator = struct {
            vec: *const Self,
            index: usize = 0,
            pub fn next(iter: *@This()) ?T {
                const ret = iter.peek();
                if (ret != null)
                    iter.index += 1;
                return ret;
            }
            pub fn peek(iter: *const @This()) ?T {
                return if (iter.index < iter.vec.data.len)
                    iter.vec.data[iter.index]
                else
                    null;
            }
            pub fn reset(iter: *@This()) void {
                iter.index = 0;
            }
        };

        pub fn begin(self: *const Self) Iterator {
            return Iterator{ .vec = self, .index = 0 };
        }

        pub fn at(self: *const Self, i: usize) *const Vec(T, taille_j) {
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

        pub fn col(self: Self, i: usize) Vec(T, taille_j) {
            assert(i < taille_i);
            return self.data[i];
        }

        pub fn row(self: Self, j: usize) Vec(T, taille_i) {
            assert(j < taille_j);
            var ret: Vec(T, taille_i) = undefined;
            for (0..taille_i) |i| {
                ret.data[i] = self.data[i].data[j];
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

        pub fn mul(self: Self, other: anytype) Mat(
            T,
            if (@TypeOf(other).dimensions == 2) @TypeOf(other).taille_i else 1,
            Self.taille_j,
        ) {
            switch (@TypeOf(other).dimensions) {
                1 => {
                    const MatA = @TypeOf(self);
                    const VecB = @TypeOf(other);
                    if (MatA.taille_i != VecB.taille) @compileError("Les matrices ne sont pas multipliables");
                    var ret: Mat(T, 1, MatA.taille_j) = undefined;
                    for (0..MatA.taille_j) |j| {
                        ret.data[j] = other.dot(self.row(j));
                    }
                    return ret;
                },
                2 => {
                    const MatA = @TypeOf(self);
                    const MatB = @TypeOf(other);
                    if (MatA.taille_i != MatB.taille_j) @compileError("Les matrices ne sont pas multipliables");
                    var ret: Mat(T, MatB.taille_i, MatA.taille_j) = undefined;
                    for (0..MatB.taille_i) |i| {
                        for (0..MatA.taille_j) |j| {
                            ret.data[i].data[j] = other.col(i).dot(self.row(j));
                        }
                    }
                    return ret;
                },
                else => unreachable,
            }
        }

        pub fn format(self: Self, writer: *std.Io.Writer) !void {
            inline for (0..Self.taille_j) |j| { //row
                try writer.print("|", .{});
                inline for (0..Self.taille_i) |i| { //col
                    try writer.print("{}", .{self.data[i].data[j]});
                    if (i != Self.taille_i - 1)
                        try writer.print(",\t", .{});
                }
                try writer.print("|", .{});
                if (j != Self.taille_j - 1)
                    try writer.print("\n", .{});
            }
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

//pub inline fn _MulResultType(comptime fields: []type) type {
//    comptime {
//        if (fields.len == 0) @compileError("tuple cannot be empty");
//        if (fields.len == 1) return fields[0];
//        if (fields.len == 2) {
//            return @TypeOf(@as(fields[0], undefined).mul(@as(fields[1], undefined)));
//        }
//
//        // calcule le type du head (a * b)
//        const head_type = @TypeOf(@as(fields[0], undefined).mul(@as(fields[1], undefined)));
//        //const head_type = @typeInfo(@TypeOf(fields[0].mul)).@"fn".return_type;
//
//        // construit un nouveau tuple type avec head_type suivi des types restants
//        var new_types: [fields.len - 1]type = undefined;
//        new_types[0] = head_type;
//        for (fields[2..], 0..) |fld, i| {
//            new_types[i + 1] = fld;
//        }
//
//        return _MulResultType(&new_types);
//    }
//}
//
//inline fn MulResultType(comptime Tuple: type) type {
//    comptime {
//        const info = @typeInfo(Tuple);
//        if (info != .@"struct") {
//            @compileError("expected tuple, got " ++ @typeName(Tuple));
//        }
//
//        const fields = info.@"struct".fields;
//
//        var type_array: [fields.len]type = undefined;
//        for (fields, 0..) |fld, i| {
//            type_array[i] = fld.type;
//        }
//
//        return _MulResultType(&type_array);
//    }
//}
//
//pub inline fn mul(args: anytype) MulResultType(@TypeOf(args)) {
//    if (args.len == 0) {
//        @compileError("tuple cannot be empty");
//    }
//    if (args.len == 1) {
//        return args[0];
//    }
//    const produit = args[0].mul(args[1]);
//    if (args.len == 2) {
//        return produit;
//    }
//
//    const type_info = @typeInfo(@TypeOf(args));
//    comptime var type_tuple_info = std.builtin.Type{ .@"struct" = .{
//        .layout = type_info.@"struct".layout,
//        .backing_integer = type_info.@"struct".backing_integer,
//        .fields = undefined,
//        .decls = type_info.@"struct".decls,
//        .is_tuple = type_info.@"struct".is_tuple,
//    } };
//    comptime var fields: [type_info.@"struct".fields.len - 1]std.builtin.Type.StructField = undefined;
//    comptime for (&fields, 0..) |*field, i| {
//        var buffer_string: [std.fmt.count("{}", .{i}):0]u8 = undefined;
//        _ = std.fmt.bufPrint(&buffer_string, "{}", .{i}) catch {
//            @compileError("mmmmmm");
//        };
//        field.* = std.builtin.Type.StructField{
//            .name = &buffer_string,
//            .type = if (i == 0)
//                MulResultType(@TypeOf(.{ args[0], args[1] }))
//            else
//                type_info.@"struct".fields[i + 1].type,
//            .default_value_ptr = type_info.@"struct".fields[i + 1].default_value_ptr,
//            .is_comptime = type_info.@"struct".fields[i + 1].is_comptime,
//            .alignment = type_info.@"struct".fields[i + 1].alignment,
//            //.is_comptime = type_info.@"struct".fields[i + 1].is_comptime,
//        };
//    };
//    type_tuple_info.@"struct".fields = &fields;
//    const TypeTuple = @Type(type_tuple_info);
//
//    var tuple: TypeTuple = undefined;
//    tuple[0] = produit;
//    comptime for (1..tuple.len) |i| {
//        tuple[i] = args[i + 1];
//    };
//    return mul(tuple);
//}

test "taille vecteur" {
    inline for (0..16) |i| {
        try expect(@sizeOf(Vec(f32, i)) == @sizeOf([i]f32));
        try expect(@sizeOf(Vec(i32, i)) == @sizeOf([i]i32));
        try expect(@sizeOf(Vec(f64, i)) == @sizeOf([i]f64));
    }
}

test "multiplication de vecteur" {
    const resultat =
        Vec4.new(.{ 1, 2, 3, -4 })
            .mul(.new(.{ 0, 1, 2, -4 }))
            .mul(.new(.{ 3, 0.5, -1, 1 }));
    try expect(resultat.eql(.new(.{ 0, 1, -6, 16 })));
}

test "mat4 x vec4" {
    const a = Mat4.new(.{
        .new(.{ 3, 0, 0, 0 }),
        .new(.{ 0, 5, 0, 0 }),
        .new(.{ 0, 0, 2, 0 }),
        .new(.{ 100, 200, 300, 1 }),
    });

    const b = Vec4.new(.{ 1, 1, 1, 1 });

    const res = a.mul(b);
    try expect(res.eql(.new(.{ 103, 205, 302, 1 })));
}

test "matrice" {
    const a = Mat4.new(.{
        .new(.{ 1, 0, 0, 0 }),
        .new(.{ 0, 1, 0, 0 }),
        .new(.{ 0, 0, 1, 0 }),
        .new(.{ 0, 0, 0, 1 }),
    });

    const b = Mat4.new(.{
        .new(.{ 1, 0, 0, 0 }),
        .new(.{ 0, 1, 0, 0 }),
        .new(.{ 0, 0, 1, 0 }),
        .new(.{ 0, 0, 0, 1 }),
    });

    const c = Mat2x4.new(.{
        .new(.{ 1, 0, 0, 0 }),
        .new(.{ 0, 1, 0, 0 }),
    });

    const d = Mat4.new(.{
        .new(.{ 1, 0, 0, 0 }),
        .new(.{ 0, 1, 0, 0 }),
        .new(.{ 0, 0, 1, 0 }),
        .new(.{ 1, 0, 0, 1 }),
    });

    try expect(a.eql(b));
    try expect(!d.eql(b));

    const produit_mat_identite = a.mul(a).mul(b).mul(a).mul(b).mul(b);
    try expect(produit_mat_identite.eql(b));

    const produit_mat_taille_variante = a.mul(c);
    try expect(produit_mat_taille_variante.eql(.new(.{
        .new(.{ 1, 0, 0, 0 }),
        .new(.{ 0, 1, 0, 0 }),
    })));
}

test "iteration" {
    const vec = Vec4.new(.{ 1, 2, 3, 4 });
    var iter = vec.begin();

    while (iter.next()) |composant| {
        try expect(composant == vec.data[iter.index - 1]);
    }
}
