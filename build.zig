const std = @import("std");

fn createGlfwModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    vulkan_mod: *std.Build.Module,
) error{FileNotFound}!*std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path("bindings/glfw.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan_mod },
        },
    });

    const glfw_dep = b.dependency("glfw", .{});
    mod.addIncludePath(glfw_dep.path("include"));
    switch (target.result.os.tag) {
        .windows => {
            mod.addCMacro("UNICODE", "");
            mod.addCMacro("_GLFW_BUILD_DLL", "");
            mod.addCMacro("_GLFW_WIN32", "");
        },
        .linux => {
            mod.addCMacro("HAVE_MEMFD_CREATE", "");
            mod.addCMacro("_DEFAULT_SOURCE", "");
            mod.addCMacro("_GLFW_WAYLAND", "");
            mod.addCMacro("_GLFW_X11", "");
        },
        else => unreachable,
    }
    const glfw_c_files = [_][]const u8{
        "context.c",
        "init.c",
        "input.c",
        "monitor.c",
        "platform.c",
        "vulkan.c",
        "window.c",
        "egl_context.c",
        "osmesa_context.c",
        "null_init.c",
        "null_monitor.c",
        "null_window.c",
        "null_joystick.c",
    };
    const glfw_c_files_linux = glfw_c_files ++ [_][]const u8{
        "posix_module.c",
        "posix_time.c",
        "posix_thread.c",
        "x11_init.c",
        "x11_monitor.c",
        "x11_window.c",
        "xkb_unicode.c",
        "glx_context.c",
        "wl_init.c",
        "wl_monitor.c",
        "wl_window.c",
        "linux_joystick.c",
        "posix_poll.c",
    };
    const glfw_c_files_windows = glfw_c_files ++ [_][]const u8{
        "win32_module.c",
        "win32_time.c",
        "win32_thread.c",
        "win32_init.c",
        "win32_joystick.c",
        "win32_monitor.c",
        "win32_window.c",
        "wgl_context.c",
    };
    const glfw_c_files_macos = glfw_c_files ++ [_][]const u8{
        "posix_thread.c",
        "posix_module.c",
        "posix_poll.c",
        "nsgl_context.m",
        "cocoa_time.c",
        "cocoa_joystick.m",
        "cocoa_init.m",
        "cocoa_window.m",
        "cocoa_monitor.m",
    };
    mod.addCSourceFiles(.{
        .root = glfw_dep.path("src"),
        .files = switch (target.result.os.tag) {
            .linux => &glfw_c_files_linux,
            .windows => &glfw_c_files_windows,
            .macos => &glfw_c_files_macos,
            else => unreachable,
        },
        .flags = &.{"-std=c99"},
    });
    //mod.linkSystemLibrary("vulkan", .{});
    //mod.linkSystemLibrary("X11", .{});
    //mod.linkSystemLibrary("Xrandr", .{});
    //mod.linkSystemLibrary("Xi", .{});
    //mod.linkSystemLibrary("Xcursor", .{});
    //mod.linkSystemLibrary("wayland-client", .{});
    //mod.linkSystemLibrary("wayland-cursor", .{});
    //mod.linkSystemLibrary("wayland-egl", .{});
    //mod.linkSystemLibrary("wayland-egl-backend", .{});
    //mod.linkSystemLibrary("wayland-protocols", .{});
    //mod.linkSystemLibrary("wayland-scanner", .{});
    //mod.linkSystemLibrary("wayland-server", .{});

    const fichiers_wayland = &.{
        "wayland",
        "viewporter",
        "xdg-shell",
        "idle-inhibit-unstable-v1",
        "pointer-constraints-unstable-v1",
        "relative-pointer-unstable-v1",
        "fractional-scale-v1",
        "xdg-activation-v1",
        "xdg-decoration-unstable-v1",
    };
    const gen_types = &.{
        .{
            .flag = "client-header",
            .postfix = "-client-protocol.h",
        },
        .{
            .flag = "private-code",
            .postfix = "-client-protocol-code.h",
        },
    };
    const wayland_scanner = b.findProgram(&.{"wayland-scanner"}, &.{}) catch |err| {
        std.log.err("wayland-scanner not found: {}", .{err});
        return err;
    };

    const wf = b.addNamedWriteFiles("protocoles-build");
    inline for (fichiers_wayland) |fichier| {
        inline for (gen_types) |gen_type| {
            const xml = glfw_dep.path("deps/wayland/" ++ fichier ++ ".xml");
            const gen_file = fichier ++ gen_type.postfix;
            const cmd = b.addSystemCommand(&.{ wayland_scanner, gen_type.flag });
            cmd.addFileArg(xml);
            _ = wf.addCopyFile(cmd.addOutputFileArg(gen_file), gen_file);
        }
    }
    mod.addIncludePath(wf.getDirectory());

    return mod;
}
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_mod = b.dependency("vulkan_zig", .{
        .registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml"),
    }).module("vulkan-zig");
    const glfw_mod = try createGlfwModule(b, target, optimize, vulkan_mod);

    const exe = b.addExecutable(.{
        .name = "afficheur_3d",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "glfw", .module = glfw_mod },
                .{ .name = "vulkan", .module = vulkan_mod },
            },
        }),
        //.use_llvm = true,
    });

    // La documentation du système de build est inexistante lol.
    const shaders = [_][]const u8{
        "defaut.frag",
        "defaut.vert",
    };
    inline for (shaders) |shader| {
        var glslc = b.addSystemCommand(&.{"glslc"});
        const shader_src = b.fmt("shaders/{s}", .{shader});
        const shader_output_name = shader ++ ".spv";
        glslc.clearEnvironment();
        glslc.addFileArg(b.path(shader_src));
        if (optimize == .Debug) {
            glslc.addArg("-g");
        }
        const output = glslc.addPrefixedOutputFileArg("-o", shader_output_name);
        //const step = b.addInstallFile(output, shader_dest);
        exe.root_module.addAnonymousImport("shader:" ++ shader_output_name, .{
            .root_source_file = output,
        });

        //b.getInstallStep().dependOn(&step.step);
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // tests

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
