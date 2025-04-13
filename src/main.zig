const std = @import("std");
const quantum = @import("quantum.zig");
const QuantumCircuit = quantum.QuantumCircuit;
const Gate = quantum.Gate;
const examples = @import("examples.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var c = try QuantumCircuit.init(allocator, 1);
    defer c.deinit();

    try c.h(0);

    try c.run();
    std.debug.print("{%}", .{c.q_reg});
}
