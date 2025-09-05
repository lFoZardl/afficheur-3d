const std = @import("std");
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

const math = @import("maths.zig");

const Erreur = error{erreur};

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    if (glfw.glfwInit() == 0) {
        return Erreur.erreur;
    }

    const fen = glfw.glfwCreateWindow(200, 200, "allo", null, null);

    if (fen == null) {
        std.debug.print("fen invalide\n", .{});
        return Erreur.erreur;
    }

    glfw.glfwMakeContextCurrent(fen);

    while (glfw.glfwWindowShouldClose(fen) == 0) {
        std.Thread.sleep(std.time.ns_per_s / 1);

        glfw.glfwSwapBuffers(fen);

        glfw.glfwPollEvents();
    }

    glfw.glfwTerminate();

    std.debug.print("All your {s} are belong to us.2\n", .{"codebase"});
}
