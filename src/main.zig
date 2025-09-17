const std = @import("std");
const assert = std.debug.assert;

const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});
const vk = @import("vulkan");

const math = @import("maths.zig");

const Application = struct {
    const Self = @This();

    fenetre: *c.GLFWwindow,
    vkb: vk.BaseWrapper = undefined,
    vki: vk.InstanceWrapper = undefined,
    instance: vk.Instance = vk.Instance.null_handle,

    const Erreur = vk.BaseWrapper.CreateInstanceError || error{
        GlfwInit,
        CreationFenetre,
        GlfwGetRequiredInstanceExtensions,
    };

    pub fn init() Self.Erreur!Self {
        if (c.glfwInit() == 0) {
            return Erreur.GlfwInit;
        }

        const fenetre = c.glfwCreateWindow(200, 200, "allo", null, null) orelse {
            std.debug.print("fen invalide\n", .{});
            return Erreur.CreationFenetre;
        };

        //déb vk
        const vk_proc: *const fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.c) vk.PfnVoidFunction = @ptrCast(&c.glfwGetInstanceProcAddress);
        const vkb = vk.BaseWrapper.load(vk_proc);

        const app_info = vk.ApplicationInfo{
            .p_application_name = "Afficheur 3D",
            .application_version = @bitCast(vk.makeApiVersion(1, 0, 0, 0)),
            .p_engine_name = null,
            .engine_version = 0,
            .api_version = @bitCast(vk.API_VERSION_1_2),
        };

        var glfw_n_extensions: u32 = undefined;
        const glfw_extensions_c = c.glfwGetRequiredInstanceExtensions(&glfw_n_extensions) orelse return Self.Erreur.GlfwGetRequiredInstanceExtensions;
        const glfw_extensions: ?[*]const [*:0]const u8 = @ptrCast(glfw_extensions_c);
        const create_info = vk.InstanceCreateInfo{
            .flags = .{},
            .p_application_info = &app_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = glfw_n_extensions,
            .pp_enabled_extension_names = glfw_extensions,
        };

        const instance = try vkb.createInstance(&create_info, null);
        const vki = vk.InstanceWrapper.load(instance, vk_proc);
        //fin vk

        return .{
            .fenetre = fenetre,
            .vkb = vkb,
            .vki = vki,
            .instance = instance,
        };
    }
    pub fn deinit(self: *Self) void {
        if (self.instance != .null_handle) self.vki.destroyInstance(self.instance, null);
        c.glfwDestroyWindow(self.fenetre);
        c.glfwTerminate();
    }

    pub fn step(self: *Self) void {
        std.Thread.sleep(std.time.ns_per_s / 60);

        c.glfwSwapBuffers(self.fenetre);

        c.glfwPollEvents();
    }

    pub fn run(self: *Self) void {
        c.glfwMakeContextCurrent(self.fenetre);
        while (c.glfwWindowShouldClose(self.fenetre) == 0) {
            self.step();
        }
    }
};

pub fn main() !void {
    var app = Application.init() catch {
        std.debug.print("Erreur\n", .{});
        return error.Unknown;
    };

    defer Application.deinit(&app); //defer app.deinit();
    Application.run(&app); //app.run();
}
