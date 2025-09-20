pub const Color = struct {
    pub const black: [:0]const u8 = "\x1B[30m";
    pub const red: [:0]const u8 = "\x1B[31m";
    pub const green: [:0]const u8 = "\x1B[32m";
    pub const yellow: [:0]const u8 = "\x1B[33m";
    pub const blue: [:0]const u8 = "\x1B[34m";
    pub const magenta: [:0]const u8 = "\x1B[35m";
    pub const cyan: [:0]const u8 = "\x1B[36m";
    pub const white: [:0]const u8 = "\x1B[37m";
    pub const default: [:0]const u8 = "\x1B[39m";
};

pub const Set = struct {
    pub const bold: [:0]const u8 = "\x1B[1m";
    pub const dim: [:0]const u8 = "\x1B[2m";
    pub const italic: [:0]const u8 = "\x1B[3m";
    pub const underline: [:0]const u8 = "\x1B[4m";
};

pub const Reset = struct {
    pub const bold: [:0]const u8 = "\x1B[22m";
    pub const dim: [:0]const u8 = "\x1B[22m";
    pub const italic: [:0]const u8 = "\x1B[23m";
    pub const underline: [:0]const u8 = "\x1B[24m";
};
