const std = @import("std");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});

pub fn getRequiredInstanceExtensions() ![]const [*:0]const u8 {
    var glfw_n_extensions: u32 = undefined;
    const glfw_extensions_c: [*c][*c]const u8 = c.glfwGetRequiredInstanceExtensions(&glfw_n_extensions) orelse return error.Unknown;
    const glfw_extensions_ptr: [*]const [*:0]const u8 = @ptrCast(glfw_extensions_c);
    const glfw_extensions: []const [*:0]const u8 = glfw_extensions_ptr[0..glfw_n_extensions];
    return glfw_extensions;
}
