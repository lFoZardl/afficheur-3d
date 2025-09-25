const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
var gpa: std.mem.Allocator = undefined;

const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});
const vk = @import("vulkan");

const glfw = @import("glfw.zig");
const terminal = @import("terminal.zig");
const math = @import("maths.zig");

const debugVulkan = true;

const QueueFamilyIndices = struct {
    const Self = @This();
    graphics_family: ?u32 = null,

    fn isComplete(self: Self) bool {
        return self.graphics_family != null;
    }
};

const Application = struct {
    const Self = @This();

    fenetre: *glfw.Window,
    vkb: vk.BaseWrapper = undefined,
    vki: vk.InstanceWrapper = undefined,
    instance: vk.Instance = vk.Instance.null_handle,
    debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle,
    physical_device: vk.PhysicalDevice = .null_handle,
    _arena: std.heap.ArenaAllocator,

    const Erreur = vk.BaseWrapper.CreateInstanceError || error{
        GlfwInit,
        CreationFenetre,
        GlfwGetRequiredInstanceExtensions,
    };

    pub fn getInstanceExtensions(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(vk.ExtensionProperties) {
        return enumerateExtensions(self.vkb, allocator);
    }
    fn enumerateExtensions(vkb: vk.BaseWrapper, allocator: std.mem.Allocator) !std.ArrayList(vk.ExtensionProperties) {
        var count: u32 = undefined;
        const resultat1 = try vkb.enumerateInstanceExtensionProperties(null, &count, null);
        if (resultat1 != .success) return error.Unknown;

        var list = try std.ArrayList(vk.ExtensionProperties).initCapacity(allocator, count);
        errdefer list.deinit(allocator);

        const resultat2 = try vkb.enumerateInstanceExtensionProperties(null, &count, @ptrCast(list.items));
        if (resultat2 != .success) return error.Unknown;

        list.items.len = count;
        return list;
    }

    pub fn getInstanceLayers(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(vk.LayerProperties) {
        return enumerateLayers(self.vkb, allocator);
    }
    fn enumerateLayers(vkb: vk.BaseWrapper, allocator: std.mem.Allocator) !std.ArrayList(vk.LayerProperties) {
        var count: u32 = undefined;
        const resultat1 = try vkb.enumerateInstanceLayerProperties(&count, null);
        if (resultat1 != .success) return error.Unknown;

        var list = try std.ArrayList(vk.LayerProperties).initCapacity(allocator, count);
        errdefer list.deinit(allocator);

        const resultat2 = try vkb.enumerateInstanceLayerProperties(&count, @ptrCast(list.items));
        if (resultat2 != .success) return error.Unknown;

        list.items.len = count;
        return list;
    }

    fn enumeratePhysicalDevices(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(vk.PhysicalDevice) {
        var count: u32 = undefined;
        const resultat1 = try self.vki.enumeratePhysicalDevices(self.instance, &count, null);
        if (resultat1 != .success) return error.Unknown;

        var list = try std.ArrayList(vk.PhysicalDevice).initCapacity(allocator, count);
        errdefer list.deinit(allocator);

        const resultat2 = try self.vki.enumeratePhysicalDevices(self.instance, &count, @ptrCast(list.items));
        if (resultat2 != .success) return error.Unknown;

        list.items.len = count;
        return list;
    }

    fn debugCallback(
        message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
        message_types: vk.DebugUtilsMessageTypeFlagsEXT,
        p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
        _: ?*anyopaque,
    ) callconv(vk.vulkan_call_conv) vk.Bool32 {
        assert(p_callback_data != null);
        const str_severity =
            if (message_severity.error_bit_ext)
                terminal.Color.red ++ "ERROR"
            else if (message_severity.warning_bit_ext)
                terminal.Color.yellow ++ "WARNING" //"\x1B[33mWARNING"
            else if (message_severity.info_bit_ext)
                terminal.Color.cyan ++ "INFO"
            else if (message_severity.verbose_bit_ext)
                "VERBOSE"
            else
                "[UNKNOWN SEVERITY]";
        const str_type =
            if (message_types.general_bit_ext)
                "general"
            else if (message_types.validation_bit_ext)
                "validation"
            else if (message_types.performance_bit_ext)
                "performance"
            else if (message_types.device_address_binding_bit_ext)
                "device_address_binding"
            else
                "[UNKOWN TYPE]";

        const str_message = (if (p_callback_data) |p|
            p.p_message orelse null
        else
            null) orelse
            "[???]";

        //{
        //    var str_objets = try std.ArrayList(u8).initCapacity(gpa, 4);
        //    defer str_objets.deinit(gpa);
        //    try str_objets.appendSlice(gpa, "[ ");
        //    if (p_callback_data) |p| {
        //        if (p.object_count > 0) {
        //            const objets = p.p_objects.?[0..p.object_count];
        //            for (objets, 0..) |objet, i| {
        //                if (i > 0) {
        //                    try str_objets.appendSlice(gpa, ", ");
        //                }
        //                try str_objets.appendSlice(gpa, objet.p_object_name orelse "???");
        //            }
        //        }
        //    }
        //    try str_objets.appendSlice(gpa, " ]");
        //}
        //catch {
        //// jsp quoi faire dans ce cas mdr
        //std.debug.panic("allocation failure", .{});
        //};

        std.log.debug(
            // severity
            terminal.Set.bold ++ terminal.Set.underline ++ "{s}" ++
                // type
                " {s}" ++ terminal.Reset.bold ++ terminal.Reset.underline ++
                // message
                "\n\t" ++ terminal.Set.italic ++ "{s}" ++ terminal.Reset.italic ++
                // objets
                "\n" ++ //terminal.Set.dim ++ "{s}" ++ terminal.Reset.dim ++
                terminal.Color.default,
            .{
                str_severity,
                str_type,
                str_message,
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
        try list.appendSlice(allocator, glfw_extensions);

        if (debugVulkan) {
            try list.append(allocator, vk.extensions.ext_debug_utils.name);
        }
        return list;
    }

    fn findQueueFamilies(self: *Self, device: vk.PhysicalDevice) !QueueFamilyIndices {
        var indices: QueueFamilyIndices = .{};
        //var _string_buffer = self._string_buffer; // sert à faire .allocator() parce que ça prends un pointeur mut

        var queue_family_count: u32 = 0;
        self.vki.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        var queue_families = try std.ArrayList(vk.QueueFamilyProperties).initCapacity(self._arena.allocator(), queue_family_count);
        defer queue_families.deinit(self._arena.allocator());
        self.vki.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.items.ptr);

        for (queue_families.items, 0..) |queue_family, i| {
            if (queue_family.queue_flags.graphics_bit) {
                indices.graphics_family = @intCast(i);
            }

            if (indices.isComplete()) {
                break;
            }
        }

        return indices;
    }
    fn isDeviceSuitable(self: *Self, device: vk.PhysicalDevice) !bool {
        const indices = try self.findQueueFamilies(device);

        return indices.isComplete();
    }
    fn pickPhysicalDevice(self: *Self) !void {
        var devices = try self.enumeratePhysicalDevices(self._arena.allocator());
        defer devices.deinit(self._arena.allocator());

        for (devices.items) |device| {
            if (try self.isDeviceSuitable(device)) {
                self.physical_device = device;
                break;
            }
        }
        if (self.physical_device == .null_handle) {
            std.log.err("no supported physical device found", .{});
            return error.Unknown;
        }
    }

    pub fn init() !Self {
        var self: Self = undefined;
        self._arena = .init(gpa);
        if (glfw.init() == 0) {
            return Erreur.GlfwInit;
        }

        self.fenetre = glfw.Window.create(200, 200, "allo", null, null) catch {
            std.debug.print("fen invalide\n", .{});
            return Erreur.CreationFenetre;
        };

        //déb vk instance
        const vk_proc: *const fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.c) vk.PfnVoidFunction = @ptrCast(&glfw.getInstanceProcAddress);
        self.vkb = vk.BaseWrapper.load(vk_proc);

        const app_info = vk.ApplicationInfo{
            .p_application_name = "Afficheur 3D",
            .application_version = @bitCast(vk.makeApiVersion(1, 0, 0, 0)),
            .p_engine_name = null,
            .engine_version = 0,
            .api_version = @bitCast(vk.API_VERSION_1_2),
        };

        var extensions = try getRequiredExtensions(self._arena.allocator());
        defer extensions.deinit(self._arena.allocator());

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

        self.instance = try self.vkb.createInstance(&create_info, null);
        self.vki = vk.InstanceWrapper.load(self.instance, vk_proc);
        //fin vk instance

        //déb vk debug messenger
        self.debug_messenger = .null_handle;
        if (debugVulkan) {
            var messenger_create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;
            populateDebugMessengerCreateInfo(&messenger_create_info);

            self.debug_messenger = try self.vki.createDebugUtilsMessengerEXT(self.instance, &messenger_create_info, null);
        }
        //fin vk debug messenger

        //déb vk devices
        try self.pickPhysicalDevice();
        //fin vk devices

        return self;
    }

    pub fn deinit(self: *Self) void {
        self._arena.deinit();
        //déb vk debug messenger
        if (debugVulkan and self.debug_messenger != .null_handle) {
            self.vki.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messenger, null);
        }
        //fin vk debug messenger

        //déb vk instance
        assert(self.instance != .null_handle);
        self.vki.destroyInstance(self.instance, null);
        //fin vk instance

        self.fenetre.destroy();
        glfw.terminate();
    }

    pub fn step(self: *Self) void {
        std.Thread.sleep(std.time.ns_per_s / 60);

        self.fenetre.swapBuffers();

        glfw.pollEvents();
    }

    pub fn run(self: *Self) void {
        self.fenetre.makeContextCurrent();
        while (!self.fenetre.shouldClose()) {
            self.step();
        }
    }
};

pub fn main() !void {
    var gpa_debug = std.heap.DebugAllocator(.{
        //.verbose_log = true,
        .safety = if (builtin.mode == .Debug) true,
    }).init;
    defer if (builtin.mode == .Debug) assert(gpa_debug.deinit() == .ok);
    gpa = gpa_debug.allocator();

    var app = Application.init() catch {
        std.debug.print("Erreur\n", .{});
        return error.Unknown;
    };
    defer app.deinit();

    var list_extensions = try app.getInstanceExtensions(app._arena.allocator());
    defer list_extensions.deinit(app._arena.allocator());

    for (list_extensions.items) |extension| {
        std.debug.print("\t{s}\n", .{extension.extension_name});
    }

    var list_layers = try app.getInstanceLayers(app._arena.allocator());
    defer list_layers.deinit(app._arena.allocator());
    for (list_layers.items) |layer| {
        std.debug.print("\t{s}\n", .{layer.layer_name});
    }
    app.run();
}
