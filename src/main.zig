const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl-bindings");
const chip8 = @import("./chip8.zig");

// Default GLFW error handling callback
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

const vertex_shader_source: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in vec2 aTexCoord;
    \\out vec2 TexCoord;
    \\void main() {
    \\    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
    \\    TexCoord = aTexCoord;
    \\}
;

const fragment_shader_source: [:0]const u8 =
    \\#version 330 core
    \\in vec2 TexCoord;
    \\out vec4 FragColor;
    \\uniform sampler2D screenTexture;
    \\void main() {
    \\    float pixel = texture(screenTexture, TexCoord).r;
    \\    FragColor = vec4(pixel, pixel, pixel, 1.0);
    \\}
;

fn createShaderProgram() !gl.GLuint {
    const vertex_shader = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertex_shader, 1, &vertex_shader_source.ptr, null);
    gl.compileShader(vertex_shader);

    const fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragment_shader, 1, &fragment_shader_source.ptr, null);
    gl.compileShader(fragment_shader);

    const shader_program = gl.createProgram();
    gl.attachShader(shader_program, vertex_shader);
    gl.attachShader(shader_program, fragment_shader);
    gl.linkProgram(shader_program);

    gl.deleteShader(vertex_shader);
    gl.deleteShader(fragment_shader);

    return shader_program;
}

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(640, 320, "Chip-8 Emulator", null, null, .{
        .context_version_major = 3,
        .context_version_minor = 3,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    }) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    const proc: glfw.GLProc = undefined;
    try gl.load(proc, glGetProcAddress);

    // Init chip8 emulator
    try chip8.init();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const rom_data = try openROM("roms/5-quirks.ch8", allocator);
    defer allocator.free(rom_data);
    try chip8.loadROM(rom_data);

    const shader_program = try createShaderProgram();

    // Create a texture for the Chip-8 screen
    var texture: gl.GLuint = undefined;
    gl.genTextures(1, &texture);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    // Set up vertex data for a fullscreen quad
    const vertices = [_]f32{
        -1.0, -1.0,  0.0, 1.0,  // Bottom-left
         1.0, -1.0,  1.0, 1.0,  // Bottom-right
         1.0,  1.0,  1.0, 0.0,  // Top-right
        -1.0,  1.0,  0.0, 0.0,  // Top-left
    };

    const indices = [_]gl.GLuint{
        0, 1, 2,
        2, 3, 0,
    };

    var vbo: gl.GLuint = undefined;
    var vao: gl.GLuint = undefined;
    var ebo: gl.GLuint = undefined;

    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    gl.genBuffers(1, &ebo);

    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(gl.GLuint) * indices.len, &indices, gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    gl.enableVertexAttribArray(1);

    gl.useProgram(shader_program);
    gl.bindVertexArray(vao);

    const target_fps: f64 = 60.0;
    const frame_time: f64 = 1.0 / target_fps;
    var last_time = glfw.getTime();

    while (!window.shouldClose()) {
        const current_time = glfw.getTime();
        const delta_time = current_time - last_time;

        if (delta_time >= frame_time) {
            processInput(window);

            try chip8.speedScaledStep();

            // Update texture with Chip-8 screen data
            var textureData: [64 * 32]u8 = undefined;
            for (0..64*32) |i| {
                textureData[i] = if (chip8.screen[i] == 1) 255 else 0;
            }
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RED, 64, 32, 0, gl.RED, gl.UNSIGNED_BYTE, &textureData);

            gl.clearColor(0.2, 0.3, 0.3, 1.0);
            gl.clear(gl.COLOR_BUFFER_BIT);

            gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

            window.swapBuffers();
            glfw.pollEvents();

            last_time = current_time;
        } else {
            // Sleep to avoid excessive CPU usage
            std.time.sleep(@intFromFloat((frame_time - delta_time) * 1000000000.0));
        }
    }
    chip8.printScreen();
    chip8.printRegisters();
}

fn processInput(window: glfw.Window) void {
    const key_map: [16]glfw.Key = .{
        glfw.Key.x,    // 0
        glfw.Key.one,    // 1
        glfw.Key.two,    // 2
        glfw.Key.three,    // 3
        glfw.Key.q,    // 4
        glfw.Key.w,    // 5
        glfw.Key.e,    // 6
        glfw.Key.a,    // 7
        glfw.Key.s,    // 8
        glfw.Key.d,    // 9
        glfw.Key.z,    // A
        glfw.Key.c,    // B
        glfw.Key.four,    // C
        glfw.Key.r,    // D
        glfw.Key.f,    // E
        glfw.Key.v,    // F
    };

    if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
        window.setShouldClose(true);
    }

        // Iterate over each key in the Chip-8 key mapping
    for (key_map, 0..key_map.len) |key, index| {
        const is_pressed = window.getKey(key) == glfw.Action.press;
        const is_released = window.getKey(key) == glfw.Action.release;
        
        // Set the key state in the Chip-8 keys array
        if (is_pressed) {
            chip8.keys[index] = true;
        } else if (is_released) {
            chip8.keys[index] = false;
        }
    }
}
