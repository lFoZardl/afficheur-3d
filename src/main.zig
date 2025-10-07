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
const validation_layers: ?[]const [*:0]const u8 =
    if (debugVulkan)
        &.{"VK_LAYER_KHRONOS_validation"}
    else
        null;

const device_extensions = [_][*:0]const u8{vk.extensions.khr_swapchain.name};

const QueueFamilyIndices = struct {
    const Self = @This();
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,

    fn isComplete(self: Self) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

const SwapChainSupportDetails = struct {
    const Self = @This();
    capabilities: vk.SurfaceCapabilitiesKHR,
    formats: std.ArrayList(vk.SurfaceFormatKHR),
    present_modes: std.ArrayList(vk.PresentModeKHR),

    fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.formats.deinit(allocator);
        self.present_modes.deinit(allocator);
    }
};

const Application = struct {
    const Self = @This();

    fenetre: *glfw.Window = undefined,

    vkb: vk.BaseWrapper = undefined,
    vki: vk.InstanceWrapper = undefined,
    vkd: vk.DeviceWrapper = undefined,

    instance: vk.Instance = vk.Instance.null_handle,
    debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle,
    surface: vk.SurfaceKHR = .null_handle,

    physical_device: vk.PhysicalDevice = .null_handle,
    device: vk.Device = .null_handle,

    graphics_queue: vk.Queue = .null_handle,
    present_queue: vk.Queue = .null_handle,

    swap_chain: vk.SwapchainKHR = .null_handle,
    swap_chain_images: ?[]vk.Image = null,
    swap_chain_image_format: vk.Format = .undefined,
    swap_chain_extent: vk.Extent2D = .{ .width = 0, .height = 0 },
    swap_chain_image_views: std.ArrayList(vk.ImageView) = .empty,

    _arena: std.heap.ArenaAllocator = undefined,

    const Erreur = vk.BaseWrapper.CreateInstanceError || error{
        GlfwInit,
        CreationFenetre,
        GlfwGetRequiredInstanceExtensions,
    };

    pub fn getInstanceExtensions(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(vk.ExtensionProperties) {
        return enumerateExtensions(self.vkb, allocator);
    }
    fn enumerateExtensions(vkb: vk.BaseWrapper, allocator: std.mem.Allocator) !std.ArrayList(vk.ExtensionProperties) {
        const alloc_extensions = try vkb.enumerateInstanceExtensionPropertiesAlloc(null, allocator);
        var list_extensions = std.ArrayList(vk.ExtensionProperties).fromOwnedSlice(alloc_extensions);
        errdefer list_extensions.deinit(allocator);
        return list_extensions;
    }

    pub fn getInstanceLayers(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(vk.LayerProperties) {
        return enumerateLayers(self.vkb, allocator);
    }
    fn enumerateLayers(vkb: vk.BaseWrapper, allocator: std.mem.Allocator) !std.ArrayList(vk.LayerProperties) {
        const alloc_layers = try vkb.enumerateInstanceLayerPropertiesAlloc(allocator);
        var list_layers = std.ArrayList(vk.LayerProperties).fromOwnedSlice(alloc_layers);
        errdefer list_layers.deinit(allocator);
        return list_layers;
    }

    fn enumeratePhysicalDevices(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(vk.PhysicalDevice) {
        const alloc_devices = try self.vki.enumeratePhysicalDevicesAlloc(self.instance, allocator);
        var list_devices = std.ArrayList(vk.PhysicalDevice).fromOwnedSlice(alloc_devices);
        errdefer list_devices.deinit(allocator);
        return list_devices;
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

        const queue_families = try self.vki.getPhysicalDeviceQueueFamilyPropertiesAlloc(device, self._arena.allocator());
        defer self._arena.allocator().free(queue_families);

        for (queue_families, 0..) |queue_family, i| {
            if (queue_family.queue_flags.graphics_bit) {
                indices.graphics_family = @intCast(i);
            }
            const presentSupport = try self.vki.getPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), self.surface);
            if (presentSupport == .true) {
                indices.present_family = @intCast(i);
            }

            if (indices.isComplete()) {
                break;
            }
        }

        return indices;
    }
    fn isDeviceSuitable(self: *Self, device: vk.PhysicalDevice) !bool {
        const indices = try self.findQueueFamilies(device);

        const extensions_supported = try self.checkDeviceExtensionSupport(device);
        var swap_chain_adequate = false;
        if (extensions_supported) {
            var swap_chain_support = try self.querySwapChainSupport(device, self._arena.allocator());
            defer swap_chain_support.deinit(self._arena.allocator());

            swap_chain_adequate =
                swap_chain_support.formats.items.len > 0 and
                swap_chain_support.present_modes.items.len > 0;
        }

        return indices.isComplete() and extensions_supported and swap_chain_adequate;
    }

    // déb fonctions pour swapchain
    fn checkDeviceExtensionSupport(self: *Self, device: vk.PhysicalDevice) !bool {
        const extensions_dispos = try self.vki.enumerateDeviceExtensionPropertiesAlloc(device, null, self._arena.allocator());
        defer self._arena.allocator().free(extensions_dispos);

        const required_extensions = device_extensions[0..];

        for (required_extensions) |required_extension| {
            for (extensions_dispos) |extensions_dispo| {
                const len = std.mem.indexOfScalar(u8, &extensions_dispo.extension_name, 0).?;
                const extensions_dispo_name = extensions_dispo.extension_name[0..len];
                if (std.mem.eql(u8, std.mem.span(required_extension), extensions_dispo_name)) {
                    break;
                }
            } else {
                return false;
            }
        }

        return true;
    }
    fn querySwapChainSupport(self: *Self, device: vk.PhysicalDevice, allocator: std.mem.Allocator) !SwapChainSupportDetails {
        assert(device != .null_handle);
        assert(self.surface != .null_handle);
        const surface_formats_alloc = try self.vki.getPhysicalDeviceSurfaceFormatsAllocKHR(device, self.surface, allocator);
        const surface_present_modes_alloc = try self.vki.getPhysicalDeviceSurfacePresentModesAllocKHR(device, self.surface, allocator);

        const details: SwapChainSupportDetails = .{
            .capabilities = try self.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(device, self.surface),
            .formats = .fromOwnedSlice(surface_formats_alloc),
            .present_modes = .fromOwnedSlice(surface_present_modes_alloc),
        };

        return details;
    }
    fn chooseSwapSurfaceFormat(formats: []const vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
        assert(formats.len > 0);
        for (formats) |available_format| {
            if (available_format.format == .b8g8r8a8_srgb and available_format.color_space == .srgb_nonlinear_khr) {
                return available_format;
            }
        }

        return formats[0];
    }
    fn chooseSwapPresentMode(present_modes: []const vk.PresentModeKHR) vk.PresentModeKHR {
        assert(present_modes.len > 0);
        for (present_modes) |available_mode| {
            if (available_mode == .mailbox_khr) {
                return available_mode;
            }
        }

        return present_modes[0];
    }
    fn chooseSwapExtent(self: *Self, capabilities: vk.SurfaceCapabilitiesKHR) vk.Extent2D {
        if (capabilities.current_extent.width != 0xFFFF_FFFF) {
            return capabilities.current_extent;
        } else {
            const taille_framebuffer = self.fenetre.getFramebufferSize();
            assert(taille_framebuffer.width > 0);
            assert(taille_framebuffer.height > 0);

            return vk.Extent2D{
                .width = std.math.clamp(@as(u32, @intCast(taille_framebuffer.width)), capabilities.min_image_extent.width, capabilities.max_image_extent.width),
                .height = std.math.clamp(@as(u32, @intCast(taille_framebuffer.height)), capabilities.min_image_extent.height, capabilities.max_image_extent.height),
            };
        }
    }
    fn createSwapChain(self: *Self) !void {
        var swap_chain_support = try self.querySwapChainSupport(self.physical_device, self._arena.allocator());
        defer swap_chain_support.deinit(self._arena.allocator());

        const surface_format = chooseSwapSurfaceFormat(swap_chain_support.formats.items);
        const present_mode = chooseSwapPresentMode(swap_chain_support.present_modes.items);
        const extent = self.chooseSwapExtent(swap_chain_support.capabilities);

        const nb_images =
            if (swap_chain_support.capabilities.max_image_count > swap_chain_support.capabilities.min_image_count)
                swap_chain_support.capabilities.min_image_count + 1
            else
                swap_chain_support.capabilities.min_image_count;

        const indices = try self.findQueueFamilies(self.physical_device);
        const queue_family_indices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
        const sharing_mode: vk.SharingMode =
            if (indices.graphics_family.? != indices.present_family.?)
                .concurrent
            else
                .exclusive;

        self.swap_chain = try self.vkd.createSwapchainKHR(self.device, &.{
            .surface = self.surface,
            .min_image_count = nb_images,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true },
            .image_sharing_mode = sharing_mode,
            .queue_family_index_count = queue_family_indices.len,
            .p_queue_family_indices = &queue_family_indices,
            .pre_transform = swap_chain_support.capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = .true,
        }, null);

        self.swap_chain_images = try self.vkd.getSwapchainImagesAllocKHR(self.device, self.swap_chain, self._arena.allocator());

        self.swap_chain_image_format = surface_format.format;
        self.swap_chain_extent = extent;
    }
    // fin fonctions pour swapchain

    fn pickPhysicalDevice(self: *Self) !void {
        var devices = try self.enumeratePhysicalDevices(self._arena.allocator());
        defer devices.deinit(self._arena.allocator());

        self.physical_device = .null_handle;
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

    fn createLogicalDevice(self: *Self) !void {
        assert(self.physical_device != .null_handle);
        const indices = try self.findQueueFamilies(self.physical_device);

        const queue_count = 1;
        const priorites = [queue_count]f32{1};

        var unique_families = std.AutoHashMap(u32, void).init(self._arena.allocator());
        defer unique_families.deinit();

        try unique_families.put(indices.graphics_family.?, {});
        try unique_families.put(indices.present_family.?, {});

        var queue_infos = try std.ArrayList(vk.DeviceQueueCreateInfo).initCapacity(self._arena.allocator(), unique_families.count());
        defer queue_infos.deinit(self._arena.allocator());

        var it = unique_families.iterator();
        while (it.next()) |entry| {
            try queue_infos.append(self._arena.allocator(), .{
                .queue_family_index = entry.key_ptr.*,
                .queue_count = queue_count,
                .p_queue_priorities = &priorites,
            });
        }

        const create_info = vk.DeviceCreateInfo{
            .queue_create_info_count = @intCast(queue_infos.items.len),
            .p_queue_create_infos = queue_infos.items.ptr,

            .enabled_extension_count = device_extensions.len,
            .pp_enabled_extension_names = &device_extensions,

            // ces champs sont dépréciés. Les implémentations à jour devraient les ignorer
            //.enabled_layer_count = validation_layers.len,
            //.pp_enabled_layer_names = &validation_layers,
        };

        self.device = try self.vki.createDevice(self.physical_device, &create_info, null);
        self.vkd = vk.DeviceWrapper.load(self.device, self.vki.dispatch.vkGetDeviceProcAddr.?);

        self.graphics_queue = self.vkd.getDeviceQueue(self.device, indices.graphics_family.?, 0);
        self.present_queue = self.vkd.getDeviceQueue(self.device, indices.present_family.?, 0);
    }

    pub fn createSurface(self: *Self) !void {
        self.surface = try self.fenetre.createSurface(self.instance, null);
    }

    fn createImageViews(self: *Self) !void {
        try self.swap_chain_image_views.resize(self._arena.allocator(), self.swap_chain_images.?.len);

        assert(self.swap_chain_images != null);
        for (self.swap_chain_images.?, self.swap_chain_image_views.items) |image, *image_view| {
            image_view.* = try self.vkd.createImageView(self.device, &.{
                .image = image,
                .view_type = .@"2d",
                .format = self.swap_chain_image_format,
                .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            }, null);
        }
    }

    pub fn init() !Self {
        var self: Self = .{};
        self._arena = .init(gpa);
        errdefer self._arena.deinit();
        if (glfw.init() == 0) {
            return Erreur.GlfwInit;
        }

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
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
            .p_application_info = &app_info,
            .enabled_layer_count = 0, //if (validation_layers) |p| p.len else 0,
            .pp_enabled_layer_names = null, //if (validation_layers) |p| p.ptr else null,
            .enabled_extension_count = @intCast(extensions.items.len),
            .pp_enabled_extension_names = extensions.items.ptr,
        };

        var debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;
        if (validation_layers) |layers| {
            create_info.enabled_layer_count = layers.len;
            create_info.pp_enabled_layer_names = layers.ptr;

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

        //déb vk surface
        try self.createSurface();
        //fin vk surface

        //déb vk physical devices
        try self.pickPhysicalDevice();
        //fin vk physical devices

        //déb vk logical devices
        try self.createLogicalDevice();
        //fin vk logical devices

        // déb vk swap chain
        try self.createSwapChain();
        // fin vk swap chain

        // déb vk image views
        try self.createImageViews();
        // fin vk image views

        return self;
    }

    pub fn deinit(self: *Self) void {
        // déb vk image views
        assert(self.swap_chain_image_views.items.len > 0);
        for (self.swap_chain_image_views.items) |image_view| {
            self.vkd.destroyImageView(self.device, image_view, null);
        }
        self.swap_chain_image_views.clearAndFree(self._arena.allocator());
        // fin vk image views

        // déb vk swap chain
        assert(self.swap_chain_images != null);
        self._arena.allocator().free(self.swap_chain_images.?);
        assert(self.swap_chain != .null_handle);
        self.vkd.destroySwapchainKHR(self.device, self.swap_chain, null);
        // fin vk swap chain

        //déb vk logical devices
        assert(self.device != .null_handle);
        self.vkd.destroyDevice(self.device, null);
        //fin vk logical devices

        //déb vk surface
        assert(self.surface != .null_handle);
        self.vki.destroySurfaceKHR(self.instance, self.surface, null);
        //fin vk surface

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
        self._arena.deinit();
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

    var app = Application.init() catch |e| {
        std.debug.print("Erreur ({})\n", .{e});
        return e;
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
