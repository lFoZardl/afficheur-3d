const std = @import("std");
const assert = std.debug.assert;
const gpa = std.heap.page_allocator;

const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});
const vk = @import("vulkan");

const glfw = @import("glfw.zig");
const math = @import("maths.zig");

const debugVulkan = true;

const Application = struct {
    const Self = @This();

    fenetre: *c.GLFWwindow,
    vkb: vk.BaseWrapper = undefined,
    vki: vk.InstanceWrapper = undefined,
    instance: vk.Instance = vk.Instance.null_handle,
    debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle,

    const Erreur = vk.BaseWrapper.CreateInstanceError || error{
        GlfwInit,
        CreationFenetre,
        GlfwGetRequiredInstanceExtensions,
        EnumerateInstanceExtensionProperties,
        EnumerateInstanceLayerProperties,
    };

    pub fn getInstanceExtensions(self: Self) !std.ArrayList(vk.ExtensionProperties) {
        return enumerateExtensions(self.vkb);
    }
    pub fn enumerateExtensions(vkb: vk.BaseWrapper) !std.ArrayList(vk.ExtensionProperties) {
        var nb_extensions: u32 = undefined;
        const resultat1 = vkb.enumerateInstanceExtensionProperties(null, &nb_extensions, null) catch |err| {
            return err;
        };
        if (resultat1 != .success) return Self.Erreur.EnumerateInstanceExtensionProperties;

        var list = try std.ArrayList(vk.ExtensionProperties).initCapacity(gpa, nb_extensions);
        errdefer list.deinit(gpa);

        const resultat2 = vkb.enumerateInstanceExtensionProperties(null, &nb_extensions, @ptrCast(list.items)) catch |err| {
            return err;
        };
        if (resultat2 != .success) return Self.Erreur.EnumerateInstanceExtensionProperties;

        list.items.len = nb_extensions;
        return list;
    }

    pub fn getInstanceLayers(self: Self) !std.ArrayList(vk.LayerProperties) {
        return enumerateLayers(self.vkb);
    }
    fn enumerateLayers(vkb: vk.BaseWrapper) !std.ArrayList(vk.LayerProperties) {
        var nb_layers: u32 = undefined;
        const resultat1 = vkb.enumerateInstanceLayerProperties(&nb_layers, null) catch |err| {
            return err;
        };
        if (resultat1 != .success) return Self.Erreur.EnumerateInstanceLayerProperties;

        var list = try std.ArrayList(vk.LayerProperties).initCapacity(gpa, nb_layers);
        errdefer list.deinit(gpa);

        const resultat2 = vkb.enumerateInstanceLayerProperties(&nb_layers, @ptrCast(list.items)) catch |err| {
            return err;
        };
        if (resultat2 != .success) return Self.Erreur.EnumerateInstanceLayerProperties;

        list.items.len = nb_layers;
        return list;
    }

    fn debugCallback(msg_severite: vk.DebugUtilsMessageSeverityFlagsEXT, msg_type: vk.DebugUtilsMessageTypeFlagsEXT, p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(vk.vulkan_call_conv) vk.Bool32 {
        assert(p_callback_data != null);
        const str_couleur_debut =
            if (msg_severite.error_bit_ext)
                "\x1B[31mERROR"
            else if (msg_severite.warning_bit_ext)
                "\x1B[33mWARNING"
            else if (msg_severite.info_bit_ext)
                "\x1B[36mINFO"
            else if (msg_severite.verbose_bit_ext)
                "VERBOSE"
            else
                "[UNKNOWN SEVERITY]\n\t";
        const str_type =
            if (msg_type.general_bit_ext)
                "general"
            else if (msg_type.validation_bit_ext)
                "validation"
            else if (msg_type.performance_bit_ext)
                "performance"
            else if (msg_type.device_address_binding_bit_ext)
                "device_address_binding"
            else
                "[UNKOWN TYPE]";

        std.log.debug(
            "\x1B[1;4m{s}" ++
                " {s}\x1B[22;24m\n\t" ++
                "\x1B[3m{s}\x1B[23m" ++
                "\x1B[39m",
            .{
                str_couleur_debut,
                str_type,
                p_callback_data.?.p_message.?,
            },
        );

        return vk.Bool32.false;
    }

    fn populateDebugMessengerCreateInfo(create_info: *vk.DebugUtilsMessengerCreateInfoEXT) void {
        create_info.* = .{
            .flags = .{},
            .message_severity = .{
                .verbose_bit_ext = true,
                .warning_bit_ext = true,
                .error_bit_ext = true,
            },
            .message_type = .{
                .general_bit_ext = true,
                .validation_bit_ext = true,
                .performance_bit_ext = true,
            },
            .pfn_user_callback = debugCallback,
            .p_user_data = null,
        };
    }

    fn getRequiredExtensions(allocator: std.mem.Allocator) !std.ArrayList([*:0]const u8) {
        const glfw_extensions = try glfw.getRequiredInstanceExtensions();
        var list = try std.ArrayList([*:0]const u8).initCapacity(allocator, glfw_extensions.len);

        // ajouter les extensions GLFW dans la liste
        try list.appendSlice(gpa, glfw_extensions);

        if (debugVulkan) {
            try list.append(allocator, vk.extensions.ext_debug_utils.name);
        }
        return list;
    }

    pub fn init() !Self {
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

        var extensions = try getRequiredExtensions(gpa);
        defer extensions.deinit(gpa);

        var create_info = vk.InstanceCreateInfo{
            .flags = .{},
            .p_application_info = &app_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = null,
            .enabled_extension_count = @intCast(extensions.items.len),
            .pp_enabled_extension_names = extensions.items.ptr,
        };

        var debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;
        if (debugVulkan) {
            const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
            create_info.enabled_layer_count = validation_layers.len;
            create_info.pp_enabled_layer_names = &validation_layers;

            populateDebugMessengerCreateInfo(&debug_create_info);
            create_info.p_next = &debug_create_info;
        }

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
        if (debugVulkan and self.debug_messenger != .null_handle) {
            self.vki.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messenger, null);
        }
        assert(self.instance != .null_handle);
        self.vki.destroyInstance(self.instance, null);
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
    defer app.deinit();

    var list_extensions = try app.getInstanceExtensions();
    defer list_extensions.deinit(gpa);

    for (list_extensions.items) |extension| {
        std.debug.print("\t{s}\n", .{extension.extension_name});
    }

    var list_layers = try app.getInstanceLayers();
    defer list_layers.deinit(gpa);
    for (list_layers.items) |layer| {
        std.debug.print("\t{s}\n", .{layer.layer_name});
    }
    app.run();
}
