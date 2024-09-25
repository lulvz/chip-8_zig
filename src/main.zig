const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl-bindings");

const chip8 = @import("./chip8.zig");

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

pub fn openROM(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(rom_path, .{});
    defer file.close();
    
    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    errdefer allocator.free(buffer);
    
    const bytes_read = try file.readAll(buffer);
    if (bytes_read != file_size) {
        return error.IncompleteRead;
    }
    
    return buffer;
}

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(640, 480, "Hello, mach-glfw!", null, null, .{
        .context_version_major = 4,
        .context_version_minor = 5,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    }) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();
    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined; try gl.load(proc, glGetProcAddress); // Init chip8 emulator
    chip8.init();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const rom_data = try openROM("ibm_logo.ch8", allocator);
    defer allocator.free(rom_data);

    try chip8.loadROM(rom_data);
    // chip8.printMemory();

    // chip8.singleStep();

    var lastTime = std.time.milliTimestamp();
    var currentTime = std.time.milliTimestamp();


    // Wait for the user to close the window.
    while (!window.shouldClose()) {
        processInput(window);

        // render
        // ------
        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        // if(chip8.drawFlag) {
        //     drawGraphics();
        // }

        window.swapBuffers();
        glfw.pollEvents();

        // if the difference between polled times is greater than the time it would take to achieve 60hz, then step and draw
        // 1000 miliseconds divided by the hz we want our screen to refresh at
        if(@as(f64, @floatFromInt(currentTime-lastTime))>(1000.0/60.0)) {
            chip8.speedScaledStep();
            lastTime = currentTime;
        }
        currentTime = std.time.milliTimestamp();
    }
    chip8.printScreen();
    chip8.printRegisters();
}

fn processInput(window: glfw.Window) void {
    if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
        window.setShouldClose(true);
    }
}
