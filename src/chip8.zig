const std = @import("std");
const Stack = @import("stack.zig").Stack;
const font = @import("font.zig").font;

const chip8 = @This();

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
var screen: [64*32]u1 = undefined;

// These timers count down to 0 at 60hz when set any value over 0
var delay_timer: u8 = undefined;
var sound_timer: u8 = undefined;

const Chip8Stack = Stack(u12, 16); // Stack type with 16 slots of type u12 because it will be used to store addresses to memory
var call_stack = Chip8Stack.init();

var keys: [16]u1 = undefined; // Pressed keys 0 to 9 and A to F

pub fn init() void {
    opcode = 0x0;
    // Set memory to all zeros
    @memset(&memory, 0x0);
    // Then we load the fontset into 0x50 onwards
    @memcpy(memory[0x50..0x50+font.len], &font);

    @memset(&V, 0x0);
    I = 0x0;
    pc = 0x200; // The program is loaded into 0x200 in the memory
    @memset(&screen, 0x0);
    delay_timer = 0x0;
    sound_timer = 0x0;
    @memset(&keys, 0x0);
}

pub fn loadROM(ROMBytes: []u8) !void {
    if (0x200 + ROMBytes.len > memory.len) {
        return error.ROMTooLarge;
    }
    @memcpy(memory[0x200..0x200+ROMBytes.len], ROMBytes);
}

pub fn step() void {
    opcode = memory[pc] << 8 | memory[pc+1];
    // switch (opcode) {
    //     0x
    // }
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