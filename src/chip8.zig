const std = @import("std");
const Stack = @import("stack.zig").Stack;
const font = @import("font.zig").font;

const chip8 = @This();

// amount of instructions to run per scaledSpeedStep
// so if we are rendering at 60hz, we would run 60*10 instructions every second 
var speed: u32 = undefined;

var opcode: u16 = undefined; // opcodes are 2 bytes long

// Memory map
// 0x000 - ox1FF -> Chip 8 interpreter
// 0x050 - 0x0A0 -> Used for the font set (0 to F)
// 0x200 - 0xFFF -> Program ROM and RAM
var memory: [4096]u8 = undefined; // memory is an array of bytes

var V: [16]u8 = undefined; // 16 V registers from 0 to 15 one byte long each
var I: u12 = undefined; // 12 bit index register
var pc: u12 = undefined; // 12 bit program counter, 12 bits allow access to 4096 places in memory

// The screen is 64 by 32 pixels, and they can either be on or off
pub var screen: [64 * 32]u1 = undefined;

// These timers count down to 0 at 60hz when set any value over 0
var delay_timer: u8 = undefined;
var sound_timer: u8 = undefined;

const Chip8Stack = Stack(u12, 16); // Stack type with 16 slots of type u12 because it will be used to store addresses to memory
var call_stack = Chip8Stack.init();

var keys: [16]bool = undefined; // Pressed keys 0 to 9 and A to F

var rand: std.Random = undefined;

pub fn init() !void {
    speed = 10;
    opcode = 0x0;
    // Set memory to all zeros
    @memset(&memory, 0x0);
    // Then we load the fontset into 0x50 onwards
    @memcpy(memory[0x50 .. 0x50 + font.len], &font);

    @memset(&V, 0x0);
    I = 0x0;
    pc = 0x200; // The program is loaded into 0x200 in the memory
    @memset(&screen, 0x0);
    delay_timer = 0x0;
    sound_timer = 0x0;
    @memset(&keys, false);

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = prng.random();
}

pub fn loadROM(ROMBytes: []u8) !void {
    if (0x200 + ROMBytes.len > memory.len) {
        return error.ROMTooLarge;
    }
    @memcpy(memory[0x200 .. 0x200 + ROMBytes.len], ROMBytes);
}

pub fn setSpeed(s: u32) void {
    speed = s;
}

pub fn singleStep() !void {
    opcode = (@as(u16, memory[pc]) << 8) | memory[pc + 1];

    pc += 2;
    // Implement these first for IBM program
    // 00E0 (clear screen)
    // 1NNN (jump)
    // 6XNN (set register VX)
    // 7XNN (add value to register VX)
    // ANNN (set index register I)
    // DXYN (display/draw)

    switch (opcode & 0xF000) {
        0x0000 => {
            switch (opcode) {
                0x00E0 => {
                    @memset(&screen, 0x0);
                },
                0x00EE => {
                    pc = try call_stack.pop();
                },
                else => {},
            }
        },
        0x1000 => {
            pc = @as(u12, @truncate(opcode & 0x0FFF));
            // std.debug.print("{x}\n", .{pc});
            // std.debug.print("{x}\n", .{(@as(u16, memory[pc]) << 8) | memory[pc + 1]});
        },
        0x2000 => {
            call_stack.push(pc);
            pc = @as(u12, @truncate(opcode & 0x0FFF));
        },
        // 3xkk
        0x3000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            const n: usize = @as(u8, @truncate(opcode&0x00FF)); // n is the amount of bytes to be read, which is also the height since every sprite is 8 in width
            if(n == V[x]) {
                pc += 2;
            }
        },
        // 4xkk
        0x4000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            const n: usize = @as(u8, @truncate(opcode&0x00FF)); // n is the amount of bytes to be read, which is also the height since every sprite is 8 in width
            if(n != V[x]) {
                pc += 2;
            }
        },
        // 5xy0
        0x5000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            const y: usize = @as(usize, (opcode&0x00F0) >> 4);
            if(V[x] == V[y]) {
                pc += 2;
            }
        },
        0x6000 => {
            V[@as(usize, (opcode&0x0F00) >> 8)] = @as(u8, @truncate(opcode & 0x00FF));
        },
        0x7000 => {
            V[@as(usize, (opcode&0x0F00) >> 8)] +%= @as(u8, @truncate(opcode & 0xFF));
        },
        0x8000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            const y: usize = @as(usize, (opcode&0x00F0) >> 4);
            switch (opcode & 0xF) {
                0x0 => {
                    V[x] = V[y];
                },
                0x1 => {
                    V[x] |= V[y];
                },
                0x2 => {
                    V[x] &= V[y];
                },
                0x3 => {
                    V[x] ^= V[y];
                },
                0x4 => {
                    const result_overflow_tuple = @addWithOverflow(V[x], V[y]);
                    V[x] = result_overflow_tuple[0];
                    V[0xF] = @as(u8, result_overflow_tuple[1]);
                },
                0x5 => {
                    const result_overflow_tuple = @subWithOverflow(V[x], V[y]);
                    V[x] = result_overflow_tuple[0];
                    V[0xF] = @as(u8, result_overflow_tuple[1]);
                },
                0x6 => {
                    V[0xF] = V[x]&0x1;
                    V[x] = V[x] >> 1;
                    // add quirks
                },
                0x7 => {
                    const result_overflow_tuple = @subWithOverflow(V[y], V[x]);
                    V[x] = result_overflow_tuple[0];
                    V[0xF] = @as(u8, result_overflow_tuple[1]);
                },
                0xE => {
                    V[0xF] = V[x]&(0x1<<7);
                    V[x] = V[x] << 1;
                },
                else => {},
            }
        },
        0x9000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            const y: usize = @as(usize, (opcode&0x00F0) >> 4);

            if(V[x] != V[y]) {
                pc += 2;
            }
        },
        0xA000 => {
            I = @as(u12, @truncate(opcode & 0x0FFF));
        },
        0xB000 => {
            pc = @as(u12, @truncate(opcode & 0x0FFF)) + @as(u12, V[0]);
        },
        0xC000 => {},
        // DXYN
        // TODO: ADD WRAP AROUND AND COLLISION
        0xD000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            const y: usize = @as(usize, (opcode&0x00F0) >> 4);
            const n: usize = @as(usize, (opcode&0x000F)); // n is the amount of bytes to be read, which is also the height since every sprite is 8 in width

            const px = V[x];
            const py = V[y];

            V[0xF] = 0; // set collision to 0

            var spriteLine: u8 = undefined;
            for(0..n) |i| {
                spriteLine = memory[@as(usize, I) + i]; 
                for(0..8) |j| {
                    screen[(@as(usize, py)+i)*64 + @as(usize, px) + j] = @as(u1, @truncate((spriteLine >> @truncate(7-j)) & 1));
                }
            }

        },
        0xE000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            switch (opcode & 0xFF) {
                0x9E => {
                    if(keys[V[x]]) {
                        pc += 2;
                    } 
                },
                0xA1 => {
                    if(!keys[V[x]]) {
                        pc += 2;
                    }
                },
                else => {},
            }
        },
        0xF000 => {
            const x: usize = @as(usize, (opcode&0x0F00) >> 8);
            switch (opcode & 0xFF) {
                0x07 => {
                    V[x] = delay_timer;
                },
                0x0A => {

                },
                0x15 => {
                    delay_timer = V[x];
                },
                0x18 => {
                    sound_timer = V[x];
                },
                0x1E => {
                    I = @addWithOverflow(I, V[x])[0];
                },
                0x29 => {

                },
                0x33 => {
                    var value = V[x];
                    memory[I+2] = value % 10; // ones
                    value = value / 10;
                    memory[I+1] = value % 10;// tens 
                    value = value / 10;
                    memory[I] = value % 10;// hundreds 
                },
                0x55 => {
                    for(0..x+1) |i| {
                        memory[@as(usize, I)+i] = V[i];
                    }
                },
                0x65 => {
                    for(0..x+1) |i| {
                        V[i] = memory[@as(usize, I)+i];
                    }
                },
                else => {},
            }
        },
        else => {
            std.debug.print("default\n", .{});
        },
    }
}

pub fn speedScaledStep() !void {
    for(0..speed) |_| {
        try singleStep();
    }
}

pub fn printMemory() void {
    std.debug.print("Memory printout:\n", .{});
    for (memory[0..], 0..) |byte, i| {
        if (i % 16 == 0) {
            std.debug.print("\n0x{X:0>3}: ", .{i});
        }
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});
}

pub fn printRegisters() void {
    std.debug.print("Registers printout:\n", .{});

    // Print V registers (V0 to VF)
    for (V, 0..) |reg, idx| {
        std.debug.print("V{d}: 0x{X:0>2}\n", .{ idx, reg });
    }

    // Print I and pc registers
    std.debug.print("I: 0x{X:0>3}\n", .{I});
    std.debug.print("PC: 0x{X:0>3}\n", .{pc});

    // Print delay_timer and sound_timer
    std.debug.print("Delay Timer: 0x{X:0>2}\n", .{delay_timer});
    std.debug.print("Sound Timer: 0x{X:0>2}\n", .{sound_timer});
}

pub fn printScreen() void {
    std.debug.print("Screen printout:\n", .{});
    for (screen[0..], 0..) |byte, i| {
        if (i % 64 == 0) {
            std.debug.print("\n{d} ", .{i/64});
        }
        std.debug.print("{X}", .{byte});
    }
    std.debug.print("\n", .{}); 
}
