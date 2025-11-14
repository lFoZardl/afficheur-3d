const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const glfw = @import("glfw.zig");
const terminal = @import("terminal.zig");
const math = @import("maths.zig");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});
const assert = std.debug.assert;

var gpa: std.mem.Allocator = undefined;

const Shader = struct {
    nom: [:0]const u8,
    stage: vk.ShaderStageFlags,
    code: [:0]const u32,

    pub fn getCodePtr(self: Shader) [*]const u32 {
        return @ptrCast(@alignCast(self.code.ptr));
    }

    pub fn getCodeLen(self: Shader) usize {
        return self.code.len * @sizeOf(@TypeOf(self.code[0]));
    }
};

const shaders = .{
    .defaut = .{
        .frag = Shader{
            .nom = "defaut.frag",
            .stage = .{ .fragment_bit = true },
            .code = @ptrCast(@alignCast(@embedFile("shader:defaut.frag.spv"))),
        },
        .vert = Shader{
            .nom = "defaut.vert",
            .stage = .{ .vertex_bit = true },
            .code = @ptrCast(@alignCast(@embedFile("shader:defaut.vert.spv"))),
        },
    },
};

const debug_vulkan = true;
const validation_layers: ?[]const [*:0]const u8 =
    if (debug_vulkan)
        &.{"VK_LAYER_KHRONOS_validation"}
    else
        null;

const max_frames_in_flight = 2;

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

const Vertex = struct {
    const Self = @This();
    position: math.Vec3,
    couleur: math.Vec3,

    const bindingDesc = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Self),
        .input_rate = .vertex,
    };

    const attributDescription = [_]vk.VertexInputAttributeDescription{
        .{
            .location = 0,
            .binding = 0,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Self, "position"),
        },
        .{
            .location = 1,
            .binding = 0,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Self, "couleur"),
        },
    };
};

const vertex_buffer_data = retour: {
    break :retour [_]Vertex{
        .{
            .position = .new(.{ -0.5, -0.5, 0.0 }),
            .couleur = .new(.{ 1.0, 0.0, 0.0 }),
        },
        .{
            .position = .new(.{ 0.5, -0.5, 0.0 }),
            .couleur = .new(.{ 0.0, 1.0, 0.0 }),
        },
        .{
            .position = .new(.{ -0.5, 0.5, 0.0 }),
            .couleur = .new(.{ 0.0, 0.0, 1.0 }),
        },
        .{
            .position = .new(.{ 0.5, 0.5, 0.0 }),
            .couleur = .new(.{ 0.0, 1.0, 1.0 }),
        },
    };
};
const index_buffer_data = retour: {
    break :retour [_]u32{
        0, 1, 2,
        2, 1, 3,
    };
};

const Application = struct {
    const Self = @This();

    fenetre: *glfw.Window = undefined,
    resized: bool = false,

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

    current_frame: u32 = 0,
    swap_chain: vk.SwapchainKHR = .null_handle,
    swap_chain_images: std.ArrayList(vk.Image) = .empty,
    swap_chain_image_format: vk.Format = .undefined,
    swap_chain_extent: vk.Extent2D = .{ .width = 0, .height = 0 },
    swap_chain_image_views: std.ArrayList(vk.ImageView) = .empty,
    swap_chain_framebuffers: std.ArrayList(vk.Framebuffer) = .empty,

    render_pass: vk.RenderPass = .null_handle,
    pipeline_layout: vk.PipelineLayout = .null_handle,
    graphics_pipeline: vk.Pipeline = .null_handle,

    vertex_buffer: vk.Buffer = .null_handle,
    vertex_buffer_memory: vk.DeviceMemory = .null_handle,
    index_buffer: vk.Buffer = .null_handle,
    index_buffer_memory: vk.DeviceMemory = .null_handle,

    command_pool: vk.CommandPool = .null_handle,
    command_buffers: std.ArrayList(vk.CommandBuffer) = .empty,

    image_available_semaphores: std.ArrayList(vk.Semaphore) = .empty,
    render_finished_semaphores: std.ArrayList(vk.Semaphore) = .empty,
    in_flight_fences: std.ArrayList(vk.Fence) = .empty,

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

        if (message_severity.error_bit_ext) {
            if (debug_vulkan) @breakpoint();
        }

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

        if (debug_vulkan) {
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
                .width = std.math.clamp(
                    @as(u32, @intCast(taille_framebuffer.width)),
                    capabilities.min_image_extent.width,
                    capabilities.max_image_extent.width,
                ),
                .height = std.math.clamp(
                    @as(u32, @intCast(taille_framebuffer.height)),
                    capabilities.min_image_extent.height,
                    capabilities.max_image_extent.height,
                ),
            };
        }
    }
    fn createSwapChain(self: *Self) !void {
        var swap_chain_support = try self.querySwapChainSupport(self.physical_device, self._arena.allocator());
        defer swap_chain_support.deinit(self._arena.allocator());

        const surface_format = chooseSwapSurfaceFormat(swap_chain_support.formats.items);
        const present_mode = chooseSwapPresentMode(swap_chain_support.present_modes.items);
        const extent = self.chooseSwapExtent(swap_chain_support.capabilities);

        const nb_images = // CECI A RAPPORT AVEC L'ERREUR DE vkQueueSubmit
            //if (swap_chain_support.capabilities.max_image_count > swap_chain_support.capabilities.min_image_count)
            //swap_chain_support.capabilities.min_image_count + 1
            //else
            //swap_chain_support.capabilities.min_image_count;
            max_frames_in_flight;

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

        self.swap_chain_images = .fromOwnedSlice(
            try self.vkd.getSwapchainImagesAllocKHR(self.device, self.swap_chain, self._arena.allocator()),
        );

        self.swap_chain_image_format = surface_format.format;
        self.swap_chain_extent = extent;
    }

    fn cleanupSwapChain(self: *Self) void {
        // déb vk framebuffers
        for (self.swap_chain_framebuffers.items) |framebuffer| {
            self.vkd.destroyFramebuffer(self.device, framebuffer, null);
        }
        self.swap_chain_framebuffers.clearAndFree(self._arena.allocator());
        // fin vk framebuffers

        // déb vk image views
        assert(self.swap_chain_image_views.items.len > 0);
        for (self.swap_chain_image_views.items) |image_view| {
            self.vkd.destroyImageView(self.device, image_view, null);
        }
        self.swap_chain_image_views.clearAndFree(self._arena.allocator());
        // fin vk image views

        // déb vk swap chain
        assert(self.swap_chain_images.items.len > 0);
        self.swap_chain_images.clearAndFree(self._arena.allocator());
        assert(self.swap_chain != .null_handle);
        self.vkd.destroySwapchainKHR(self.device, self.swap_chain, null);
        // fin vk swap chain
    }
    fn recreateSwapChain(self: *Self) !void {
        var taille = self.fenetre.getFramebufferSize();
        while (taille.height < 1 or taille.width < 1) {
            taille = self.fenetre.getFramebufferSize();
            glfw.waitEvents();
        }

        try self.vkd.deviceWaitIdle(self.device);

        self.cleanupSwapChain();

        try self.createSwapChain();
        try self.createImageViews();
        try self.createFramebuffers();
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
        try self.swap_chain_image_views.resize(self._arena.allocator(), self.swap_chain_images.items.len);

        assert(self.swap_chain_images.items.len > 0);
        for (self.swap_chain_images.items, self.swap_chain_image_views.items) |image, *image_view| {
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

    fn createRenderPass(self: *Self) !void {
        const color_attachment = [_]vk.AttachmentDescription{
            .{
                .format = self.swap_chain_image_format,
                .samples = .{ .@"1_bit" = true },
                .load_op = .clear,
                .store_op = .store,
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = .undefined,
                .final_layout = .present_src_khr,
            },
        };
        const color_attachment_ref = [_]vk.AttachmentReference{
            .{
                .attachment = 0,
                .layout = .color_attachment_optimal,
            },
        };
        const subpass = [_]vk.SubpassDescription{
            .{
                .pipeline_bind_point = .graphics,
                .color_attachment_count = color_attachment_ref.len,
                .p_color_attachments = &color_attachment_ref,
            },
        };
        const dependencies = [_]vk.SubpassDependency{
            .{
                .src_subpass = vk.SUBPASS_EXTERNAL,
                .dst_subpass = 0,
                .src_stage_mask = .{ .color_attachment_output_bit = true },
                .src_access_mask = .{},
                .dst_stage_mask = .{ .color_attachment_output_bit = true },
                .dst_access_mask = .{ .color_attachment_write_bit = true },
                .dependency_flags = .{},
            },
        };
        self.render_pass = try self.vkd.createRenderPass(self.device, &.{
            .attachment_count = color_attachment.len,
            .p_attachments = &color_attachment,
            .subpass_count = subpass.len,
            .p_subpasses = &subpass,
            .dependency_count = 1,
            .p_dependencies = &dependencies,
        }, null);
    }

    fn createGraphicsPipeline(self: *Self) !void {
        const vert_shader_module = try self.vkd.createShaderModule(self.device, &.{
            .flags = .{},
            .code_size = shaders.defaut.vert.getCodeLen(),
            .p_code = shaders.defaut.vert.getCodePtr(),
        }, null);
        const frag_shader_module = try self.vkd.createShaderModule(self.device, &.{
            .flags = .{},
            .code_size = shaders.defaut.frag.getCodeLen(),
            .p_code = shaders.defaut.frag.getCodePtr(),
        }, null);
        defer self.vkd.destroyShaderModule(self.device, vert_shader_module, null);
        defer self.vkd.destroyShaderModule(self.device, frag_shader_module, null);

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .flags = .{},
                .stage = shaders.defaut.vert.stage,
                .module = vert_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .flags = .{},
                .stage = shaders.defaut.frag.stage,
                .module = frag_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
        };

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .flags = .{},
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @ptrCast(&Vertex.bindingDesc),
            .vertex_attribute_description_count = Vertex.attributDescription.len,
            .p_vertex_attribute_descriptions = &Vertex.attributDescription,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .flags = .{},
            .topology = .triangle_list,
            .primitive_restart_enable = .false,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = undefined,
            .scissor_count = 1,
            .p_scissors = undefined,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .flags = .{},
            .depth_clamp_enable = .false,
            .rasterizer_discard_enable = .false,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true, .front_bit = false },
            .front_face = .clockwise,
            .depth_bias_enable = .false,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .flags = .{},
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = .false,
            .min_sample_shading = 1,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = .false,
            .alpha_to_one_enable = .false,
        };

        const color_blend_attachment = [_]vk.PipelineColorBlendAttachmentState{.{
            .blend_enable = .false,
            .src_color_blend_factor = .one,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        }};

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .flags = .{},
            .logic_op_enable = .false,
            .logic_op = .copy,
            .attachment_count = color_blend_attachment.len,
            .p_attachments = &color_blend_attachment,
            .blend_constants = [_]f32{ 0, 0, 0, 0 },
        };
        const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .flags = .{},
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        self.pipeline_layout = try self.vkd.createPipelineLayout(self.device, &.{
            .flags = .{},
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        }, null);

        const pipeline_info = [_]vk.GraphicsPipelineCreateInfo{.{
            .flags = .{},
            .stage_count = shader_stages.len,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_info,
            .p_input_assembly_state = &input_assembly,
            .p_tessellation_state = null,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterizer,
            .p_multisample_state = &multisampling,
            .p_depth_stencil_state = null,
            .p_color_blend_state = &color_blending,
            .p_dynamic_state = &dynamic_state,
            .layout = self.pipeline_layout,
            .render_pass = self.render_pass,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        }};

        const resultat = try self.vkd.createGraphicsPipelines(
            self.device,
            .null_handle,
            pipeline_info.len,
            &pipeline_info,
            null,
            @ptrCast(&self.graphics_pipeline),
        );

        if (resultat != .success) {
            std.debug.print("creation du pipeline graphique a échoué : {}", .{resultat});
        }
    }
    fn createFramebuffers(self: *Self) !void {
        try self.swap_chain_framebuffers.resize(
            self._arena.allocator(),
            self.swap_chain_image_views.items.len,
        );

        assert(self.swap_chain_framebuffers.items.len == self.swap_chain_image_views.items.len);
        for (0..self.swap_chain_image_views.items.len) |i| {
            const attachments = [_]vk.ImageView{
                self.swap_chain_image_views.items[i],
            };

            self.swap_chain_framebuffers.items[i] = .null_handle;
            self.swap_chain_framebuffers.items[i] = try self.vkd.createFramebuffer(
                self.device,
                &.{
                    .render_pass = self.render_pass,
                    .attachment_count = attachments.len,
                    .p_attachments = &attachments,
                    .width = self.swap_chain_extent.width,
                    .height = self.swap_chain_extent.height,
                    .layers = 1,
                },
                null,
            );
        }
    }
    fn createCommandPool(self: *Self) !void {
        const queue_family_indices = try self.findQueueFamilies(self.physical_device);

        const pool_info = vk.CommandPoolCreateInfo{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = queue_family_indices.graphics_family.?,
        };

        self.command_pool = try self.vkd.createCommandPool(self.device, &pool_info, null);
    }

    fn createVertexBuffer(self: *Self) !void {
        const size = @sizeOf(@TypeOf(vertex_buffer_data));

        const buffer_creation_staging = try self.createBuffer(
            size,
            .{
                .transfer_src_bit = true,
            },
            .{
                .host_visible_bit = true,
                .host_coherent_bit = true,
            },
        );

        {
            const data = try self.vkd.mapMemory(self.device, buffer_creation_staging.buffer_memory, 0, size, .{});
            defer self.vkd.unmapMemory(self.device, buffer_creation_staging.buffer_memory);
            @memcpy(
                @as(
                    [*]@TypeOf(vertex_buffer_data[0]),
                    @ptrCast(@alignCast(data)),
                ),
                &vertex_buffer_data,
            );
        }

        const buffer_creation_vertex = try self.createBuffer(
            size,
            .{
                .transfer_dst_bit = true,
                .vertex_buffer_bit = true,
            },
            .{
                .device_local_bit = true,
            },
        );
        self.vertex_buffer = buffer_creation_vertex.buffer;
        self.vertex_buffer_memory = buffer_creation_vertex.buffer_memory;

        try self.copyBuffer(buffer_creation_staging.buffer, buffer_creation_vertex.buffer, size);

        self.vkd.destroyBuffer(self.device, buffer_creation_staging.buffer, null);
        self.vkd.freeMemory(self.device, buffer_creation_staging.buffer_memory, null);
    }
    fn createIndexBuffer(self: *Self) !void {
        const size = @sizeOf(@TypeOf(index_buffer_data));

        const buffer_creation_staging = try self.createBuffer(
            size,
            .{
                .transfer_src_bit = true,
            },
            .{
                .host_visible_bit = true,
                .host_coherent_bit = true,
            },
        );

        {
            const data = try self.vkd.mapMemory(self.device, buffer_creation_staging.buffer_memory, 0, size, .{});
            defer self.vkd.unmapMemory(self.device, buffer_creation_staging.buffer_memory);
            @memcpy(
                @as(
                    [*]@TypeOf(index_buffer_data[0]),
                    @ptrCast(@alignCast(data)),
                ),
                &index_buffer_data,
            );
        }

        const buffer_creation_index = try self.createBuffer(
            size,
            .{
                .transfer_dst_bit = true,
                .index_buffer_bit = true,
            },
            .{
                .device_local_bit = true,
            },
        );
        self.index_buffer = buffer_creation_index.buffer;
        self.index_buffer_memory = buffer_creation_index.buffer_memory;

        try self.copyBuffer(buffer_creation_staging.buffer, buffer_creation_index.buffer, size);

        self.vkd.destroyBuffer(self.device, buffer_creation_staging.buffer, null);
        self.vkd.freeMemory(self.device, buffer_creation_staging.buffer_memory, null);
    }
    fn copyBuffer(self: *Self, src_buffer: vk.Buffer, dst_buffer: vk.Buffer, size: vk.DeviceSize) !void {
        var command_buffer: vk.CommandBuffer = .null_handle;
        try self.vkd.allocateCommandBuffers(
            self.device,
            &.{
                .command_pool = self.command_pool,
                .level = .primary,
                .command_buffer_count = 1,
            },
            (&command_buffer)[0..1],
        );
        defer self.vkd.freeCommandBuffers(self.device, self.command_pool, 1, (&command_buffer)[0..1]);

        {
            //const p_begin_info: *const vk.CommandBufferBeginInfo = &.{ .flags = .{ .one_time_submit_bit = true } };
            try self.vkd.beginCommandBuffer(
                command_buffer,
                &.{ .flags = .{ .one_time_submit_bit = true } },
            );
            const p_regions = [1]vk.BufferCopy{.{
                .src_offset = 0,
                .dst_offset = 0,
                .size = size,
            }};
            self.vkd.cmdCopyBuffer(
                command_buffer,
                src_buffer,
                dst_buffer,
                1,
                &p_regions,
            );
            try self.vkd.endCommandBuffer(command_buffer);
        }

        const p_submit = [1]vk.SubmitInfo{.{
            .command_buffer_count = 1,
            .p_command_buffers = (&command_buffer)[0..1],
        }};
        try self.vkd.queueSubmit(
            self.graphics_queue,
            1,
            &p_submit,
            .null_handle,
        );
        try self.vkd.queueWaitIdle(self.graphics_queue);
    }
    fn createBuffer(
        self: *Self,
        size: vk.DeviceSize,
        usage: vk.BufferUsageFlags,
        properties: vk.MemoryPropertyFlags,
    ) !struct {
        buffer: vk.Buffer,
        buffer_memory: vk.DeviceMemory,
    } {
        const buffer_info = vk.BufferCreateInfo{
            .size = size,
            .usage = usage,
            .sharing_mode = .exclusive,
        };
        const buffer = try self.vkd.createBuffer(self.device, &buffer_info, null);

        const mem_requirements = self.vkd.getBufferMemoryRequirements(self.device, buffer);

        const alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = mem_requirements.size,
            .memory_type_index = try findMemoryType(self, mem_requirements.memory_type_bits, properties),
        };

        const buffer_memory = try self.vkd.allocateMemory(self.device, &alloc_info, null);

        try self.vkd.bindBufferMemory(self.device, buffer, buffer_memory, 0);

        return .{
            .buffer = buffer,
            .buffer_memory = buffer_memory,
        };
    }
    fn findMemoryType(self: *Self, type_filter: u32, props: vk.MemoryPropertyFlags) !u32 {
        const mem_props = self.vki.getPhysicalDeviceMemoryProperties(self.physical_device);
        const mem_types = mem_props.memory_types[0..mem_props.memory_type_count];
        //const mem_heaps = mem_props.memory_heaps[0..mem_props.memory_heap_count];

        for (mem_types, 0..) |mem_type, i| {
            if (type_filter & (@as(u32, 1) << @intCast(i)) != 0 and (mem_type.property_flags.intersect(props)) == props) {
                return @intCast(i);
            }
        } else {
            return error.Unknown;
        }
    }

    fn createCommandBuffers(self: *Self) !void {
        try self.command_buffers.resize(self._arena.allocator(), max_frames_in_flight);

        try self.vkd.allocateCommandBuffers(
            self.device,
            &.{
                .command_pool = self.command_pool,
                .level = .primary,
                .command_buffer_count = @intCast(self.command_buffers.items.len),
            },
            self.command_buffers.items.ptr,
        );
    }
    fn recordCommandBuffer(self: *Self, command_buffer: vk.CommandBuffer, image_index: u32) !void {
        try self.vkd.beginCommandBuffer(command_buffer, &.{});

        const clear_values = [_]vk.ClearValue{.{
            .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
        }};

        const render_pass_info = vk.RenderPassBeginInfo{
            .render_pass = self.render_pass,
            .framebuffer = self.swap_chain_framebuffers.items[image_index],
            .render_area = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.swap_chain_extent,
            },
            .clear_value_count = clear_values.len,
            .p_clear_values = &clear_values,
        };

        self.vkd.cmdBeginRenderPass(command_buffer, &render_pass_info, .@"inline");
        {
            self.vkd.cmdBindPipeline(command_buffer, .graphics, self.graphics_pipeline);

            const vertex_buffers = [_]vk.Buffer{self.vertex_buffer};
            const offsets = [_]vk.DeviceSize{0};
            self.vkd.cmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffers, &offsets);
            self.vkd.cmdBindIndexBuffer(command_buffer, self.index_buffer, 0, .uint32);

            const viewports = [_]vk.Viewport{.{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(self.swap_chain_extent.width),
                .height = @floatFromInt(self.swap_chain_extent.height),
                .min_depth = 0,
                .max_depth = 1,
            }};
            self.vkd.cmdSetViewport(command_buffer, 0, viewports.len, &viewports);

            const scissors = [_]vk.Rect2D{.{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.swap_chain_extent,
            }};
            self.vkd.cmdSetScissor(command_buffer, 0, scissors.len, &scissors);

            //self.vkd.cmdDraw(command_buffer, @intCast(vertex_buffer_data.len), 1, 0, 0);
            self.vkd.cmdDrawIndexed(command_buffer, @intCast(index_buffer_data.len), 1, 0, 0, 0);
        }
        self.vkd.cmdEndRenderPass(command_buffer);

        try self.vkd.endCommandBuffer(command_buffer);
    }
    fn createSyncObjects(self: *Self) !void {
        try self.image_available_semaphores.resize(self._arena.allocator(), max_frames_in_flight);
        try self.render_finished_semaphores.resize(self._arena.allocator(), max_frames_in_flight);
        try self.in_flight_fences.resize(self._arena.allocator(), max_frames_in_flight);

        for (
            self.image_available_semaphores.items,
            self.render_finished_semaphores.items,
            self.in_flight_fences.items,
        ) |
            *image_available_semaphore,
            *render_finished_semaphore,
            *in_flight_fence,
        | {
            image_available_semaphore.* = try self.vkd.createSemaphore(self.device, &.{ .flags = .{} }, null);
            render_finished_semaphore.* = try self.vkd.createSemaphore(self.device, &.{ .flags = .{} }, null);
            in_flight_fence.* = try self.vkd.createFence(self.device, &.{ .flags = .{ .signaled_bit = true } }, null);
        }
    }

    pub fn init(self: *Self) !void {
        self.* = .{};
        self._arena = .init(gpa);
        errdefer self._arena.deinit();
        if (glfw.init() == 0) {
            return Erreur.GlfwInit;
        }

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_TRUE);
        self.fenetre = glfw.Window.create(200, 200, "allo", null, null) catch {
            std.debug.print("fenetre invalide\n", .{});
            return Erreur.CreationFenetre;
        };

        self.fenetre.setUserPointer(self);
        _ = self.fenetre.setFramebufferResizeCallback(opaque {
            fn _(window: *glfw.Window, _: i32, _: i32) callconv(.c) void {
                var self_ptr: ?*Self = @ptrCast(@alignCast(window.getUserPointer()));
                self_ptr.?.resized = true;
            }
        }._);

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
        if (debug_vulkan) {
            var messenger_create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;
            populateDebugMessengerCreateInfo(&messenger_create_info);

            self.debug_messenger = try self.vki.createDebugUtilsMessengerEXT(self.instance, &messenger_create_info, null);
        }
        //fin vk debug messenger

        try self.createSurface();
        try self.pickPhysicalDevice();
        try self.createLogicalDevice();
        try self.createSwapChain();
        try self.createImageViews();
        try self.createRenderPass();
        try self.createGraphicsPipeline();
        try self.createFramebuffers();
        try self.createCommandPool();
        try self.createVertexBuffer();
        try self.createIndexBuffer();
        try self.createCommandBuffers();
        try self.createSyncObjects();
    }

    pub fn deinit(self: *Self) void {
        self.cleanupSwapChain();
        // déb vk syncObjects
        for (
            self.image_available_semaphores.items,
            self.render_finished_semaphores.items,
            self.in_flight_fences.items,
        ) |
            *image_available_semaphore,
            *render_finished_semaphore,
            *in_flight_fence,
        | {
            self.vkd.destroySemaphore(self.device, image_available_semaphore.*, null);
            self.vkd.destroySemaphore(self.device, render_finished_semaphore.*, null);
            self.vkd.destroyFence(self.device, in_flight_fence.*, null);
        }
        // fin vk syncObjects

        // déb vk command pool
        assert(self.command_pool != .null_handle);
        self.vkd.destroyCommandPool(self.device, self.command_pool, null);
        // fin vk command pool

        // déb vk graphics pipeline
        assert(self.graphics_pipeline != .null_handle);
        self.vkd.destroyPipeline(self.device, self.graphics_pipeline, null);
        self.graphics_pipeline = .null_handle;
        assert(self.pipeline_layout != .null_handle);
        self.vkd.destroyPipelineLayout(self.device, self.pipeline_layout, null);
        self.pipeline_layout = .null_handle;
        // fin vk graphics pipeline

        // déb vk render pass
        assert(self.render_pass != .null_handle);
        self.vkd.destroyRenderPass(self.device, self.render_pass, null);
        self.render_pass = .null_handle;
        // fin vk render pass

        // déb vk index buffer
        assert(self.index_buffer != .null_handle);
        self.vkd.destroyBuffer(self.device, self.index_buffer, null);
        self.index_buffer = .null_handle;
        // fin vk index buffer

        // déb vk index buffer_memory
        assert(self.index_buffer_memory != .null_handle);
        self.vkd.freeMemory(self.device, self.index_buffer_memory, null);
        self.index_buffer_memory = .null_handle;
        // fin vk index buffer_memory

        // déb vk buffer
        assert(self.vertex_buffer != .null_handle);
        self.vkd.destroyBuffer(self.device, self.vertex_buffer, null);
        self.vertex_buffer = .null_handle;
        // fin vk buffer

        // déb vk buffer_memory
        assert(self.vertex_buffer_memory != .null_handle);
        self.vkd.freeMemory(self.device, self.vertex_buffer_memory, null);
        self.vertex_buffer_memory = .null_handle;
        // fin vk buffer_memory

        //déb vk logical devices
        assert(self.device != .null_handle);
        self.vkd.destroyDevice(self.device, null);
        self.device = .null_handle;
        //fin vk logical devices

        //déb vk surface
        assert(self.surface != .null_handle);
        self.vki.destroySurfaceKHR(self.instance, self.surface, null);
        self.surface = .null_handle;
        //fin vk surface

        //déb vk debug messenger
        if (debug_vulkan and self.debug_messenger != .null_handle) {
            self.vki.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messenger, null);
        }
        self.debug_messenger = .null_handle;
        //fin vk debug messenger

        //déb vk instance
        assert(self.instance != .null_handle);
        self.vki.destroyInstance(self.instance, null);
        self.instance = .null_handle;
        //fin vk instance

        self.fenetre.destroy();
        self.fenetre = undefined;
        glfw.terminate();

        // deinit manuel de tous les membres allouant de la mémoire.
        self.in_flight_fences.deinit(self._arena.allocator());
        self.render_finished_semaphores.deinit(self._arena.allocator());
        self.image_available_semaphores.deinit(self._arena.allocator());
        self.command_buffers.deinit(self._arena.allocator());
        self.swap_chain_framebuffers.deinit(self._arena.allocator());
        self.swap_chain_image_views.deinit(self._arena.allocator());
        self.swap_chain_images.deinit(self._arena.allocator());

        self._arena.deinit();
    }

    fn draw(self: *Self) !void {
        const frame_index = self.current_frame % max_frames_in_flight;
        const render_finished_semaphore = self.render_finished_semaphores.items[frame_index];
        const image_available_semaphore = self.image_available_semaphores.items[frame_index];
        const in_flight_fence = self.in_flight_fences.items[frame_index];
        const command_buffer = self.command_buffers.items[frame_index];

        _ = try self.vkd.waitForFences(
            self.device,
            1,
            &.{in_flight_fence},
            .true,
            std.math.maxInt(u64),
        );

        const result = self.vkd.acquireNextImageKHR(
            self.device,
            self.swap_chain,
            std.math.maxInt(u64),
            image_available_semaphore,
            .null_handle,
        ) catch |e| switch (e) {
            error.OutOfDateKHR => {
                try self.recreateSwapChain();
                return;
            },
            else => |err| {
                return err;
            },
        };

        // reset seulement la fence si on draw
        try self.vkd.resetFences(self.device, 1, &.{in_flight_fence});

        try self.vkd.resetCommandBuffer(command_buffer, .{});
        try self.recordCommandBuffer(command_buffer, result.image_index);

        const wait_semaphores = [_]vk.Semaphore{image_available_semaphore};
        const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        const signal_semaphores = [_]vk.Semaphore{render_finished_semaphore};

        // parfois il y a une erreur ici...
        _ = try self.vkd.queueSubmit(
            self.graphics_queue,
            1,
            &.{.{
                .wait_semaphore_count = wait_semaphores.len,
                .p_wait_semaphores = &wait_semaphores,
                .p_wait_dst_stage_mask = &wait_stages,
                .command_buffer_count = 1,
                .p_command_buffers = &.{command_buffer},
                .signal_semaphore_count = signal_semaphores.len,
                .p_signal_semaphores = &signal_semaphores,
            }},
            in_flight_fence,
        );

        const result_present = self.vkd.queuePresentKHR(self.present_queue, &.{
            .wait_semaphore_count = signal_semaphores.len,
            .p_wait_semaphores = &signal_semaphores,
            .swapchain_count = 1,
            .p_swapchains = &.{self.swap_chain},
            .p_image_indices = &.{result.image_index},
            .p_results = null,
        }) catch |e| switch (e) {
            error.OutOfDateKHR => {
                std.debug.print("SwapChain recréée!\n", .{});
                try self.recreateSwapChain();
                return;
            },
            else => |err| {
                return err;
            },
        };

        if (result_present == .suboptimal_khr or self.resized == true) {
            self.resized = false;
            try self.recreateSwapChain();
            return;
        }

        self.current_frame += 1;
    }

    pub fn step(self: *Self) void {
        std.Thread.sleep(std.time.ns_per_s / 60);

        self.fenetre.swapBuffers();

        glfw.pollEvents();

        self.draw() catch |e| {
            std.debug.print("erreur dans draw : {}", .{e});
        };
    }

    pub fn run(self: *Self) !void {
        self.fenetre.makeContextCurrent();
        while (!self.fenetre.shouldClose()) {
            self.step();
        }

        try self.vkd.deviceWaitIdle(self.device);
    }
};

pub fn main() !void {
    var gpa_debug = std.heap.DebugAllocator(.{
        //.verbose_log = true,
        .safety = if (builtin.mode == .Debug) true,
    }).init;
    defer if (builtin.mode == .Debug) assert(gpa_debug.deinit() == .ok);
    gpa = gpa_debug.allocator();

    var app: Application = undefined;
    app.init() catch |e| {
        std.debug.print("Erreur ({})\n", .{e});
        return e;
    };
    defer app.deinit();

    //var list_extensions = try app.getInstanceExtensions(app._arena.allocator());
    //defer list_extensions.deinit(app._arena.allocator());
    //for (list_extensions.items) |extension| {
    //std.debug.print("\t{s}\n", .{extension.extension_name});
    //}
    //var list_layers = try app.getInstanceLayers(app._arena.allocator());
    //defer list_layers.deinit(app._arena.allocator());
    //for (list_layers.items) |layer| {
    //std.debug.print("\t{s}\n", .{layer.layer_name});
    //}

    try app.run();
}
