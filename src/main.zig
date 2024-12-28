const std = @import("std");
const QuantumCircuit = @import("quantum.zig").QuantumCircuit;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var circuit = try QuantumCircuit.init(allocator, 3);
    defer circuit.deinit();

    try circuit.x(0);
    circuit.barrier();
    try circuit.h(0);
    try circuit.x(1);
    try circuit.cx(0, 1);
    try circuit.swap(1, 2);
    try circuit.cx(0, 1);
    try circuit.swap(1, 2);

    // for (circuit.gates.items) |gate| {
    //     std.debug.print("at {d}\n{}\n", .{ gate.time, gate.matrix });
    // }

    try circuit.run();

    std.debug.print("{|>}\n", .{circuit.q_reg});
}
