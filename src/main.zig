const std = @import("std");
const quantum = @import("quantum.zig");
const QuantumCircuit = quantum.QuantumCircuit;
const Gate = quantum.Gate;
const Complex = @import("complex.zig").Complex;
const Matrix = @import("matrix.zig").Matrix(Complex);
const U = quantum.U;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const toffoli = try Gate.controlled(
        allocator,
        quantum.controlled_not,
    );
    defer allocator.free(toffoli.values);

    var circuit = try QuantumCircuit.init(allocator, 3);
    defer circuit.deinit();

    try circuit.x(0);
    circuit.barrier();
    try circuit.h(0);
    try circuit.x(1);
    try circuit.cx(0, 1);
    try circuit.cx(0, 2);
    try circuit.addGate(&toffoli, &.{ 0, 2, 1 });

    // for (circuit.gates.items) |gate| {
    //     std.debug.print("at {d}\n{}\n", .{ gate.time, gate.matrix });
    // }

    try circuit.run();

    std.debug.print("{|>}\n", .{circuit.q_reg});
}
