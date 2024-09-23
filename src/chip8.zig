const std = @import("std");
const Stack = @import("stack.zig").Stack;

const chip8 = @This();

var opcode: u16 = undefined; // opcodes are 2 bytes long

// Memory map
// 0x000 - ox1FF -> Chip 8 interpreter
// 0x050 - 0x0A0 -> Used for the font set (0 to F)
// 0x200 - 0xFFF -> Program ROM and RAM
var memory: [4096]u8 = undefined; // memory is an array of bytes

var V: [16]u8 = undefined; // V registers from 0 to 15
var I: u12 = undefined; // 12 bit index register
var pc: u12 = undefined; // 12 bit program counter, 12 bits allow access to 4096 places in memory

var screen: [64*32]u1 = undefined;

// These timers count down to 0 at 60hz when set any value over 0
var delay_timer: u8 = undefined;
var sound_timer: u8 = undefined;

const Chip8Stack = Stack(u16, 16); // Stack type with 16 slots of type u16
var call_stack = Chip8Stack.init();

var keys: [16]u1 = undefined; // Pressed keys 0 to 9 and A to F

pub fn init() void {

}
