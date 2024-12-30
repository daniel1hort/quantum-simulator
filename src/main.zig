const std = @import("std");
const quantum = @import("quantum.zig");
const QuantumCircuit = quantum.QuantumCircuit;
const Gate = quantum.Gate;
const examples = @import("examples.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try examples.init_controlled_gates(allocator);
    defer examples.deinit_controlled_gates(allocator);

    try examples.simple_grover(allocator);
    try examples.sat_solver(allocator);
    try examples.parallel_sat_solver(allocator);
}
