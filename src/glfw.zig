const std = @import("std");
const assert = std.debug.assert;
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});
const vk = @import("vulkan");

pub const init: fn () callconv(.c) i32 = c.glfwInit;
pub const terminate = c.glfwTerminate;

pub fn getVersion() struct { major: i32, minor: i32, rev: i32 } {
    var major: i32 = undefined;
    var minor: i32 = undefined;
    var rev: i32 = undefined;
    c.glfwGetVersion(&major, &minor, &rev);
    return .{ .major = major, .minor = minor, .rev = rev };
}
pub const getVersionString: fn () [*c]const u8 = c.glfwGetVersionString;
pub fn getError() struct { error_code: i32, description: [*:0]const u8 } {
    var description: [*:0]const u8 = undefined;
    const error_code = c.glfwGetError(&description);
    return .{ .error_code = error_code, .description = description };
}
//glfwSetErrorCallback
pub const getPlatform: fn () i32 = c.glfwGetPlatform;
pub const platformSupported: fn (i32) i32 = c.glfwPlatformSupported;
pub fn getMonitors() ?[]*Monitor {
    var len: i32 = undefined;
    const ptr: [*c]*Monitor = @ptrCast(c.glfwGetMonitors(&len));
    return [len]ptr;
}
pub fn getPrimaryMonitor() ?*Monitor {
    return @ptrCast(c.glfwGetPrimaryMonitor());
}

pub const Vidmode = c.GLFWvidmode;
pub const Gammaramp = c.GLFWgammaramp;

pub const Monitor = opaque {
    const Self = @This();

    //pub fn getPrimaryMonitor() ?*GLFWmonitor;
    pub fn getMonitorPos(monitor: ?*Monitor) struct { xpos: i32, ypos: i32 } {
        var xpos: i32 = undefined;
        var ypos: i32 = undefined;
        c.glfwGetMonitorPos(@ptrCast(monitor), &xpos, &ypos);
        return .{ .xpos = xpos, .ypos = ypos };
    }
    pub fn getMonitorWorkarea(monitor: ?*Monitor) struct { xpos: i32, ypos: i32, width: i32, height: i32 } {
        var xpos: i32 = undefined;
        var ypos: i32 = undefined;
        var width: i32 = undefined;
        var height: i32 = undefined;
        c.glfwGetMonitorWorkarea(@ptrCast(monitor), &xpos, &ypos, &width, &height);
        return .{ .xpos = xpos, .ypos = ypos, .width = width, .height = height };
    }
    pub fn getMonitorPhysicalSize(monitor: ?*Monitor) struct { widthMM: i32, heightMM: i32 } {
        var widthMM: i32 = undefined;
        var heightMM: i32 = undefined;
        c.glfwGetMonitorPhysicalSize(@ptrCast(monitor), &widthMM, &heightMM);
        return .{ .widthMM = widthMM, .heightMM = heightMM };
    }
    pub fn getMonitorContentScale(monitor: ?*Monitor) struct { xscale: f32, yscale: f32 } {
        var xscale: f32 = undefined;
        var yscale: f32 = undefined;
        c.glfwGetMonitorContentScale(@ptrCast(monitor), &xscale, &yscale);
        return .{ .xscale = xscale, .yscale = yscale };
    }
    pub fn getMonitorName(monitor: ?*Monitor) ?[*:0]const u8 {
        return c.glfwGetMonitorName(@ptrCast(monitor));
    }
    pub fn setMonitorUserPointer(monitor: ?*Monitor, pointer: ?*anyopaque) void {
        return c.glfwSetMonitorUserPointer(@ptrCast(monitor), pointer);
    }
    pub fn getMonitorUserPointer(monitor: ?*Monitor) ?*anyopaque {
        return c.glfwGetMonitorUserPointer(@ptrCast(monitor));
    }
    //pub fn setMonitorCallback(callback: c.GLFWmonitorfun) GLFWmonitorfun;
    pub fn getVideoModes(monitor: ?*Monitor) []const Vidmode {
        var len: c_int = undefined;
        const ptr: [*c]const Vidmode = @ptrCast(c.glfwGetVideoModes(@ptrCast(monitor), &len));
        return [len]ptr;
    }
    pub fn getVideoMode(monitor: ?*Monitor) ?*const Vidmode {
        return @ptrCast(c.glfwGetVideoMode(@ptrCast(monitor)));
    }
    pub fn setGamma(monitor: ?*Monitor, gamma: f32) void {
        return c.glfwSetGamma(@ptrCast(monitor), gamma);
    }
    pub fn getGammaRamp(monitor: ?*Monitor) !*const Gammaramp {
        return @ptrCast(c.glfwGetGammaRamp(@ptrCast(monitor)) orelse error.Unknown);
    }
    pub fn setGammaRamp(monitor: ?*Monitor, ramp: *const Gammaramp) void {
        return c.glfwSetGammaRamp(@ptrCast(monitor), ramp);
    }
};

pub const Window = opaque {
    const Self = @This();

    pub fn create(
        width: i32,
        height: i32,
        title: [*:0]const u8,
        monitor: ?*Monitor,
        share: ?*Self,
    ) !*Self {
        return @ptrCast(
            c.glfwCreateWindow(width, height, title, @ptrCast(monitor), @ptrCast(share)) orelse return error.Unknown,
        );
    }
    pub fn destroy(self: *Self) void {
        return c.glfwDestroyWindow(@ptrCast(self));
    }

    pub fn shouldClose(self: *Self) bool {
        return c.glfwWindowShouldClose(@ptrCast(self)) != 0;
    }
    pub fn setShouldClose(self: *Self, value: i32) void {
        return c.glfwSetWindowShouldClose(@ptrCast(self), value);
    }
    pub fn getTitle(self: *Self) [*:0]const u8 {
        return c.glfwGetWindowTitle(@ptrCast(self));
    }
    pub fn setTitle(self: *Self, title: [*:0]const u8) void {
        return c.glfwSetWindowTitle(@ptrCast(self), title);
    }
    pub fn setIcon(self: *Self, images: []const Image) void {
        return c.glfwSetWindowIcon(@ptrCast(self), images.len, images.ptr);
    }
    pub fn getPos(self: *Self) struct { x: i32, y: i32 } {
        var xpos: i32 = undefined;
        var ypos: i32 = undefined;
        c.glfwGetWindowPos(@ptrCast(self), &xpos, &ypos);
        return .{ .x = xpos, .y = ypos };
    }
    pub fn setPos(self: *Self, xpos: i32, ypos: i32) void {
        return c.glfwSetWindowPos(@ptrCast(self), xpos, ypos);
    }
    pub fn getSize(self: *Self) struct { x: i32, y: i32 } {
        var xpos: i32 = undefined;
        var ypos: i32 = undefined;
        c.glfwGetWindowSize(@ptrCast(self), &xpos, &ypos);
        return .{ .x = xpos, .y = ypos };
    }
    pub fn setSizeLimits(
        self: *Self,
        minwidth: i32,
        minheight: i32,
        maxwidth: i32,
        maxheight: i32,
    ) void {
        return c.glfwSetWindowSizeLimits(@ptrCast(self), minwidth, minheight, maxwidth, maxheight);
    }
    pub fn setAspectRatio(self: *Self, numer: i32, denom: i32) void {
        return c.glfwSetWindowAspectRatio(@ptrCast(self), numer, denom);
    }
    pub fn setSize(self: *Self, width: i32, height: i32) void {
        return c.glfwSetWindowSize(@ptrCast(self), width, height);
    }
    pub fn getFramebufferSize(self: *Self) struct { width: i32, height: i32 } {
        var width: i32 = undefined;
        var height: i32 = undefined;
        c.glfwGetFramebufferSize(@ptrCast(self), &width, &height);
        return .{ .width = width, .height = height };
    }
    pub fn getFrameSize(self: *Self) struct { left: i32, top: i32, right: i32, bottom: i32 } {
        var left: i32 = undefined;
        var top: i32 = undefined;
        var right: i32 = undefined;
        var bottom: i32 = undefined;
        c.glfwGetWindowFrameSize(@ptrCast(self), &left, &top, &right, &bottom);
        return .{ .left = left, .top = top, .right = right, .bottom = bottom };
    }
    pub fn getContentScale(self: *Self) struct { xscale: f32, yscale: f32 } {
        var xscale: f32 = undefined;
        var yscale: f32 = undefined;
        c.glfwGetWindowContentScale(@ptrCast(self), &xscale, &yscale);
        return .{ .xscale = xscale, .yscale = yscale };
    }
    pub fn getWindowOpacity(self: *Self) f32 {
        return c.glfwGetWindowOpacity(@ptrCast(self));
    }
    pub fn setWindowOpacity(self: *Self, opacity: f32) void {
        return c.glfwSetWindowOpacity(@ptrCast(self), opacity);
    }

    pub fn iconify(self: *Self) void {
        return c.glfwIconifyWindow(@ptrCast(self));
    }
    pub fn restore(self: *Self) void {
        return c.glfwRestoreWindow(@ptrCast(self));
    }
    pub fn maximize(self: *Self) void {
        return c.glfwMaximizeWindow(@ptrCast(self));
    }
    pub fn show(self: *Self) void {
        return c.glfwShowWindow(@ptrCast(self));
    }
    pub fn hide(self: *Self) void {
        return c.glfwHideWindow(@ptrCast(self));
    }
    pub fn focus(self: *Self) void {
        return c.glfwFocusWindow(@ptrCast(self));
    }
    pub fn requestAttention(self: *Self) void {
        return c.glfwRequestWindowAttention(@ptrCast(self));
    }

    pub fn glfwGetWindowMonitor(self: *Self) ?*Monitor {
        return @ptrCast(c.glfwGetWindowMonitor(@ptrCast(self)));
    }
    pub fn glfwSetWindowMonitor(
        self: *Self,
        monitor: ?*Monitor,
        xpos: i32,
        ypos: i32,
        width: i32,
        height: i32,
        refreshRate: i32,
    ) void {
        assert(refreshRate >= -1);
        return c.glfwSetWindowMonitor(@ptrCast(self), @ptrCast(monitor), xpos, ypos, width, height, refreshRate);
    }
    pub fn getWindowAttrib(self: *Self, attrib: WindowAttribute) i32 {
        return c.glfwGetWindowAttrib(@ptrCast(self), @intFromEnum(attrib));
    }
    pub fn setWindowAttrib(self: *Self, attrib: WindowAttribute, value: bool) void {
        return c.glfwSetWindowAttrib(@ptrCast(self), @intFromEnum(attrib), value);
    }

    pub fn getInputMode(self: ?*Self, mode: i32) i32 {
        return c.glfwGetInputMode(@ptrCast(self), mode);
    }
    pub fn setInputMode(self: ?*Self, mode: i32, value: i32) void {
        return c.glfwSetInputMode(@ptrCast(self), mode, value);
    }

    pub fn setClipboardString(self: *Self, string: [*:0]const u8) void {
        return c.glfwSetClipboardString(@ptrCast(self), string);
    }
    pub fn getClipboardString(self: *Self) [*:0]const u8 {
        return c.glfwGetClipboardString(@ptrCast(self));
    }

    pub fn makeContextCurrent(self: *Self) void {
        return c.glfwMakeContextCurrent(@ptrCast(self));
    }
    pub fn swapBuffers(self: *Self) void {
        return c.glfwSwapBuffers(@ptrCast(self));
    }
};

pub const Image = struct {
    width: i32,
    height: i32,
    pixels: [*]u8,
};
pub const Monitorfun = c.GLFWmonitorfun;

pub const pollEvents = c.glfwPollEvents;
pub const waitEvents = c.glfwWaitEvents;
pub const waitEventsTimeout = c.glfwWaitEventsTimeout;
pub const postEmptyEvent = c.glfwPostEmptyEvent;

pub const getTime = c.glfwGetTime;
pub const setTime = c.glfwSetTime;
pub const getTimerValue = c.glfwGetTimerValue;
pub const getTimerFrequency = c.glfwGetTimerFrequency;
//pub const makeContextCurrent = c.glfwMakeContextCurrent;
pub fn getCurrentContext() ?*Window {
    return @ptrCast(c.glfwGetCurrentContext());
}
//pub const swapBuffers = c.glfwSwapBuffers;
pub const swapInterval: fn (interval: i32) void = c.glfwSwapInterval;
pub fn getRequiredInstanceExtensions() ![]const [*:0]const u8 {
    var count: u32 = undefined;
    const c_ptr: [*c][*c]const u8 = c.glfwGetRequiredInstanceExtensions(&count) orelse return error.Unknown;
    const ptr: [*]const [*:0]const u8 = @ptrCast(c_ptr);
    const slice: []const [*:0]const u8 = ptr[0..count];
    return slice;
}
pub const getInstanceProcAddress = c.glfwGetInstanceProcAddress;

pub const Key = enum(c_int) {
    // printable keys
    space = c.GLFW_KEY_SPACE,
    apostrophe = c.GLFW_KEY_APOSTROPHE,
    comma = c.GLFW_KEY_COMMA,
    minus = c.GLFW_KEY_MINUS,
    period = c.GLFW_KEY_PERIOD,
    slash = c.GLFW_KEY_SLASH,
    _0 = c.GLFW_KEY_0,
    _1 = c.GLFW_KEY_1,
    _2 = c.GLFW_KEY_2,
    _3 = c.GLFW_KEY_3,
    _4 = c.GLFW_KEY_4,
    _5 = c.GLFW_KEY_5,
    _6 = c.GLFW_KEY_6,
    _7 = c.GLFW_KEY_7,
    _8 = c.GLFW_KEY_8,
    _9 = c.GLFW_KEY_9,
    semicolon = c.GLFW_KEY_SEMICOLON,
    equal = c.GLFW_KEY_EQUAL,
    a = c.GLFW_KEY_A,
    b = c.GLFW_KEY_B,
    c = c.GLFW_KEY_C,
    d = c.GLFW_KEY_D,
    e = c.GLFW_KEY_E,
    f = c.GLFW_KEY_F,
    g = c.GLFW_KEY_G,
    h = c.GLFW_KEY_H,
    i = c.GLFW_KEY_I,
    j = c.GLFW_KEY_J,
    k = c.GLFW_KEY_K,
    l = c.GLFW_KEY_L,
    m = c.GLFW_KEY_M,
    n = c.GLFW_KEY_N,
    o = c.GLFW_KEY_O,
    p = c.GLFW_KEY_P,
    q = c.GLFW_KEY_Q,
    r = c.GLFW_KEY_R,
    s = c.GLFW_KEY_S,
    t = c.GLFW_KEY_T,
    u = c.GLFW_KEY_U,
    v = c.GLFW_KEY_V,
    w = c.GLFW_KEY_W,
    x = c.GLFW_KEY_X,
    y = c.GLFW_KEY_Y,
    z = c.GLFW_KEY_Z,
    left_bracket = c.GLFW_KEY_LEFT_BRACKET,
    backslash = c.GLFW_KEY_BACKSLASH,
    right_bracket = c.GLFW_KEY_RIGHT_BRACKET,
    grave_accent = c.GLFW_KEY_GRAVE_ACCENT,
    world_1 = c.GLFW_KEY_WORLD_1,
    world_2 = c.GLFW_KEY_WORLD_2,
    //function keys
    escape = c.GLFW_KEY_ESCAPE,
    enter = c.GLFW_KEY_ENTER,
    tab = c.GLFW_KEY_TAB,
    backspace = c.GLFW_KEY_BACKSPACE,
    insert = c.GLFW_KEY_INSERT,
    delete = c.GLFW_KEY_DELETE,
    right = c.GLFW_KEY_RIGHT,
    left = c.GLFW_KEY_LEFT,
    down = c.GLFW_KEY_DOWN,
    up = c.GLFW_KEY_UP,
    page_up = c.GLFW_KEY_PAGE_UP,
    page_down = c.GLFW_KEY_PAGE_DOWN,
    home = c.GLFW_KEY_HOME,
    end = c.GLFW_KEY_END,
    caps_lock = c.GLFW_KEY_CAPS_LOCK,
    scroll_lock = c.GLFW_KEY_SCROLL_LOCK,
    num_lock = c.GLFW_KEY_NUM_LOCK,
    print_screen = c.GLFW_KEY_PRINT_SCREEN,
    pause = c.GLFW_KEY_PAUSE,
    f1 = c.GLFW_KEY_F1,
    f2 = c.GLFW_KEY_F2,
    f3 = c.GLFW_KEY_F3,
    f4 = c.GLFW_KEY_F4,
    f5 = c.GLFW_KEY_F5,
    f6 = c.GLFW_KEY_F6,
    f7 = c.GLFW_KEY_F7,
    f8 = c.GLFW_KEY_F8,
    f9 = c.GLFW_KEY_F9,
    f10 = c.GLFW_KEY_F10,
    f11 = c.GLFW_KEY_F11,
    f12 = c.GLFW_KEY_F12,
    f13 = c.GLFW_KEY_F13,
    f14 = c.GLFW_KEY_F14,
    f15 = c.GLFW_KEY_F15,
    f16 = c.GLFW_KEY_F16,
    f17 = c.GLFW_KEY_F17,
    f18 = c.GLFW_KEY_F18,
    f19 = c.GLFW_KEY_F19,
    f20 = c.GLFW_KEY_F20,
    f21 = c.GLFW_KEY_F21,
    f22 = c.GLFW_KEY_F22,
    f23 = c.GLFW_KEY_F23,
    f24 = c.GLFW_KEY_F24,
    f25 = c.GLFW_KEY_F25,
    kp_0 = c.GLFW_KEY_KP_0,
    kp_1 = c.GLFW_KEY_KP_1,
    kp_2 = c.GLFW_KEY_KP_2,
    kp_3 = c.GLFW_KEY_KP_3,
    kp_4 = c.GLFW_KEY_KP_4,
    kp_5 = c.GLFW_KEY_KP_5,
    kp_6 = c.GLFW_KEY_KP_6,
    kp_7 = c.GLFW_KEY_KP_7,
    kp_8 = c.GLFW_KEY_KP_8,
    kp_9 = c.GLFW_KEY_KP_9,
    kp_decimal = c.GLFW_KEY_KP_DECIMAL,
    kp_divide = c.GLFW_KEY_KP_DIVIDE,
    kp_multiply = c.GLFW_KEY_KP_MULTIPLY,
    kp_substract = c.GLFW_KEY_KP_SUBTRACT,
    kp_add = c.GLFW_KEY_KP_ADD,
    kp_enter = c.GLFW_KEY_KP_ENTER,
    kp_equal = c.GLFW_KEY_KP_EQUAL,
    left_shift = c.GLFW_KEY_LEFT_SHIFT,
    left_control = c.GLFW_KEY_LEFT_CONTROL,
    left_alt = c.GLFW_KEY_LEFT_ALT,
    left_super = c.GLFW_KEY_LEFT_SUPER,
    right_shift = c.GLFW_KEY_RIGHT_SHIFT,
    right_control = c.GLFW_KEY_RIGHT_CONTROL,
    right_alt = c.GLFW_KEY_RIGHT_ALT,
    right_super = c.GLFW_KEY_RIGHT_SUPER,
    menu = c.GLFW_KEY_MENU,
};

pub const MouseButton = enum(c_int) {
    _1 = c.GLFW_MOUSE_BUTTON_1, // left
    _2 = c.GLFW_MOUSE_BUTTON_2, // right
    _3 = c.GLFW_MOUSE_BUTTON_3, // middle
    _4 = c.GLFW_MOUSE_BUTTON_4,
    _5 = c.GLFW_MOUSE_BUTTON_5,
    _6 = c.GLFW_MOUSE_BUTTON_6,
    _7 = c.GLFW_MOUSE_BUTTON_7,
    _8 = c.GLFW_MOUSE_BUTTON_8,
    //left = c.GLFW_MOUSE_BUTTON_LEFT,
    //right = c.GLFW_MOUSE_BUTTON_RIGHT,
    //middle = c.GLFW_MOUSE_BUTTON_MIDDLE,
};

pub const GamepadButton = enum(c_int) {
    a = c.GLFW_GAMEPAD_BUTTON_A, // cross
    b = c.GLFW_GAMEPAD_BUTTON_B, // circle
    x = c.GLFW_GAMEPAD_BUTTON_X, // square
    y = c.GLFW_GAMEPAD_BUTTON_Y, // triangle
    left_bumper = c.GLFW_GAMEPAD_BUTTON_LEFT_BUMPER,
    right_bumper = c.GLFW_GAMEPAD_BUTTON_RIGHT_BUMPER,
    back = c.GLFW_GAMEPAD_BUTTON_BACK,
    start = c.GLFW_GAMEPAD_BUTTON_START,
    guide = c.GLFW_GAMEPAD_BUTTON_GUIDE,
    left_thumb = c.GLFW_GAMEPAD_BUTTON_LEFT_THUMB,
    right_thumb = c.GLFW_GAMEPAD_BUTTON_RIGHT_THUMB,
    dpad_up = c.GLFW_GAMEPAD_BUTTON_DPAD_UP,
    dpad_right = c.GLFW_GAMEPAD_BUTTON_DPAD_RIGHT,
    dpad_down = c.GLFW_GAMEPAD_BUTTON_DPAD_DOWN,
    dpad_left = c.GLFW_GAMEPAD_BUTTON_DPAD_LEFT,
    //cross = c.GLFW_GAMEPAD_BUTTON_CROSS,
    //circle = c.GLFW_GAMEPAD_BUTTON_CIRCLE,
    //square = c.GLFW_GAMEPAD_BUTTON_SQUARE,
    //triangle = c.GLFW_GAMEPAD_BUTTON_TRIANGLE,
};

pub const GamepadAxis = enum(c_int) {
    left_x = c.GLFW_GAMEPAD_AXIS_LEFT_X,
    left_y = c.GLFW_GAMEPAD_AXIS_LEFT_Y,
    right_x = c.GLFW_GAMEPAD_AXIS_RIGHT_X,
    right_y = c.GLFW_GAMEPAD_AXIS_RIGHT_Y,
    left_trigger = c.GLFW_GAMEPAD_AXIS_LEFT_TRIGGER,
    right_trigger = c.GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER,
};

pub const WindowAttribute = enum(c_int) {
    // window related
    FOCUSED = c.GLFW_FOCUSED,
    ICONIFIED = c.GLFW_ICONIFIED,
    RESIZABLE = c.GLFW_RESIZABLE,
    VISIBLE = c.GLFW_VISIBLE,
    DECORATED = c.GLFW_DECORATED,
    AUTO_ICONIFY = c.GLFW_AUTO_ICONIFY,
    FLOATING = c.GLFW_FLOATING,
    MAXIMIZED = c.GLFW_MAXIMIZED,
    TRANSPARENT_FRAMEBUFFER = c.GLFW_TRANSPARENT_FRAMEBUFFER,
    HOVERED = c.GLFW_HOVERED,
    FOCUS_ON_SHOW = c.GLFW_FOCUS_ON_SHOW,
    MOUSE_PASSTHROUGH = c.GLFW_MOUSE_PASSTHROUGH,
    // context related
    CLIENT_API = c.GLFW_CLIENT_API,
    CONTEXT_VERSION_MAJOR = c.GLFW_CONTEXT_VERSION_MAJOR,
    CONTEXT_VERSION_MINOR = c.GLFW_CONTEXT_VERSION_MINOR,
    CONTEXT_REVISION = c.GLFW_CONTEXT_REVISION,
    CONTEXT_ROBUSTNESS = c.GLFW_CONTEXT_ROBUSTNESS,
    OPENGL_FORWARD_COMPAT = c.GLFW_OPENGL_FORWARD_COMPAT,
    CONTEXT_DEBUG = c.GLFW_CONTEXT_DEBUG,
    OPENGL_PROFILE = c.GLFW_OPENGL_PROFILE,
    CONTEXT_RELEASE_BEHAVIOR = c.GLFW_CONTEXT_RELEASE_BEHAVIOR,
    CONTEXT_NO_ERROR = c.GLFW_CONTEXT_NO_ERROR,
    CONTEXT_CREATION_API = c.GLFW_CONTEXT_CREATION_API,
    // framebuffer related
    DOUBLEBUFFER = c.GLFW_DOUBLEBUFFER,
};
