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
    opcode = (@as(u16, memory[pc]) << 8) | memory[pc + 1];

    // Implement these first for IBM program
    // 00E0 (clear screen)
    // 1NNN (jump)
    // 6XNN (set register VX)
    // 7XNN (add value to register VX)
    // ANNN (set index register I)
    // DXYN (display/draw)

    switch(opcode & 0xF000) {
      0x0000 => {
        switch(opcode) {
          0x00E0 => {},
          0x00EE => {},
          else => {},
        }
      },
      0x1000 => {},
      0x2000 => {},
      0x3000 => {},
      0x4000 => {},
      0x5000 => {},
      0x6000 => {},
      0x7000 => {},
      0x8000 => {
        switch(opcode & 0xF) {
          0x0 => {},
          0x1 => {},
          0x2 => {},
          0x3 => {},
          0x4 => {},
          0x5 => {},
          0x6 => {},
          0x7 => {},
          0xE => {},
          else => {},
        }
      },
      0x9000 => {},
      0xA000 => {},
      0xB000 => {},
      0xC000 => {},
      0xD000 => {},
      0xE000 => {
        switch(opcode & 0xFF) {
          0x9E => {},
          0xA1 => {},
          else => {},
        }
      },
      0xF000 => {
        switch(opcode & 0xFF) {
          0x07 => {},
          0x0A => {},
          0x15 => {},
          0x18 => {},
          0x1E => {},
          0x29 => {},
          0x33 => {},
          0x55 => {},
          0x65 => {},
          else => {},
        }
      },
      else => {},
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
        std.debug.print("V{d}: 0x{X:0>2}\n", .{idx, reg});
    }

    // Print I and pc registers
    std.debug.print("I: 0x{X:0>3}\n", .{I});
    std.debug.print("PC: 0x{X:0>3}\n", .{pc});

    // Print delay_timer and sound_timer
    std.debug.print("Delay Timer: 0x{X:0>2}\n", .{delay_timer});
    std.debug.print("Sound Timer: 0x{X:0>2}\n", .{sound_timer});
}
