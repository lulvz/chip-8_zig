const std = @import("std");

pub fn Stack(comptime T: type, comptime stack_size: usize) type {
    return struct {
        items: [stack_size]T,
        current_location: usize = 0,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .items = undefined,
            };
        }

        pub fn push(self: *Self, value: T) void {
            if (self.current_location >= stack_size) {
                std.debug.print("Stack Overflow!\n", .{});
                return;
            }
            self.items[self.current_location] = value;
            self.current_location += 1;
        }

        pub fn pop(self: *Self) !T {
            if (self.current_location == 0) {
                std.debug.print("Stack Underflow!\n", .{});
                return error.StackUnderflow;
            }
            self.current_location -= 1;
            return self.items[self.current_location];
        }

        pub fn top(self: *const Self) !T {
            if (self.current_location == 0) {
                std.debug.print("Stack is empty!\n", .{});
                return error.StackEmpty;
            }
            return self.items[self.current_location - 1];
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.current_location == 0;
        }

        pub fn isFull(self: *const Self) bool {
            return self.current_location == stack_size;
        }
    };
}