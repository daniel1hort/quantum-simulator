const std = @import("std");
const Allocator = std.mem.Allocator;
const quantum = @import("quantum.zig");
const QuantumCircuit = quantum.QuantumCircuit;
const Gate = quantum.Gate;
const Complex = @import("complex.zig");
const Matrix = @import("matrix.zig");

var toffoli2: Matrix = undefined;
var toffoli3: Matrix = undefined;
var cz: Matrix = undefined;
var ccz: Matrix = undefined;

pub fn init_controlled_gates(allocator: Allocator) !void {
    toffoli2 = try Gate.controlled(allocator, quantum.controlled_not);
    toffoli3 = try Gate.controlled(allocator, toffoli2);
    cz = try Gate.controlled(allocator, quantum.pauli_z);
    ccz = try Gate.controlled(allocator, cz);
}
pub fn deinit_controlled_gates(allocator: Allocator) void {
    allocator.free(toffoli2.values);
    allocator.free(toffoli3.values);
    allocator.free(cz.values);
    allocator.free(ccz.values);
}

pub fn simple_grover(allocator: Allocator) !void {
    var circuit = try QuantumCircuit.init(allocator, 3);
    defer circuit.deinit();

    try circuit.h(0);
    try circuit.h(1);

    try circuit.addGate(&toffoli2, &.{ 0, 1, 2 });
    try circuit.z(2);
    try circuit.addGate(&toffoli2, &.{ 0, 1, 2 });

    try circuit.h(0);
    try circuit.h(1);
    try circuit.x(0);
    try circuit.x(1);
    try circuit.addGate(&cz, &.{ 0, 1 });
    try circuit.x(0);
    try circuit.x(1);
    try circuit.h(0);
    try circuit.h(1);

    try circuit.run();
    std.debug.print("{|>}\n", .{circuit.q_reg});
}

pub fn sat_solver(allocator: Allocator) !void {
    var circuit = try QuantumCircuit.init(allocator, 7);
    defer circuit.deinit();

    try circuit.h(0);
    try circuit.h(2);
    try circuit.h(4);

    try sat_solver_oracle(&circuit);
    try sat_solver_diffuser(&circuit);
    try sat_solver_oracle(&circuit);
    try sat_solver_diffuser(&circuit);

    try circuit.run();
    std.debug.print("{%}\n", .{circuit.q_reg});
}

fn sat_solver_oracle(circuit: *QuantumCircuit) !void {
    try circuit.x(1);
    try circuit.x(3);
    try circuit.x(5);

    try circuit.x(0);
    try circuit.cx(0, 1);
    try circuit.x(0);

    try circuit.x(2);
    try circuit.addGate(&toffoli2, &.{ 0, 2, 3 });
    try circuit.x(2);

    try circuit.x(4);
    try circuit.addGate(&toffoli2, &.{ 0, 4, 5 });
    try circuit.x(4);

    try circuit.addGate(&toffoli3, &.{ 1, 3, 5, 6 });
    try circuit.z(6);
    try circuit.addGate(&toffoli3, &.{ 1, 3, 5, 6 });

    try circuit.x(4);
    try circuit.addGate(&toffoli2, &.{ 0, 4, 5 });
    try circuit.x(4);

    try circuit.x(2);
    try circuit.addGate(&toffoli2, &.{ 0, 2, 3 });
    try circuit.x(2);

    try circuit.x(0);
    try circuit.cx(0, 1);
    try circuit.x(0);

    try circuit.x(1);
    try circuit.x(3);
    try circuit.x(5);
}

fn sat_solver_diffuser(circuit: *QuantumCircuit) !void {
    try circuit.h(0);
    try circuit.h(2);
    try circuit.h(4);
    try circuit.x(0);
    try circuit.x(2);
    try circuit.x(4);
    try circuit.addGate(&ccz, &.{ 0, 2, 4 });
    try circuit.x(0);
    try circuit.x(2);
    try circuit.x(4);
    try circuit.h(0);
    try circuit.h(2);
    try circuit.h(4);
}

pub fn parallel_sat_solver(allocator: Allocator) !void {
    var circuit = try QuantumCircuit.init(allocator, 9);
    defer circuit.deinit();

    try circuit.h(0);
    try circuit.cx(0, 2);
    try circuit.cx(0, 5);
    try circuit.h(3);
    try circuit.h(6);

    try parallel_sat_solver_oracle(&circuit);
    try parallel_sat_solver_diffuser(&circuit);
    try parallel_sat_solver_oracle(&circuit);
    try parallel_sat_solver_diffuser(&circuit);

    try circuit.run();
    std.debug.print("{|>}\n", .{circuit.q_reg});
}

fn parallel_sat_solver_oracle(circuit: *QuantumCircuit) !void {
    try circuit.x(1);
    try circuit.x(4);
    try circuit.x(7);

    try circuit.x(0);
    try circuit.cx(0, 1);

    try circuit.x(3);
    try circuit.addGate(&toffoli2, &.{ 2, 3, 4 });

    try circuit.x(6);
    try circuit.addGate(&toffoli2, &.{ 5, 6, 7 });

    try circuit.addGate(&toffoli3, &.{ 1, 4, 7, 8 });
    try circuit.z(8);
    try circuit.addGate(&toffoli3, &.{ 1, 4, 7, 8 });

    try circuit.addGate(&toffoli2, &.{ 5, 6, 7 });
    try circuit.x(6);

    try circuit.addGate(&toffoli2, &.{ 2, 3, 4 });
    try circuit.x(3);

    try circuit.cx(0, 1);
    try circuit.x(0);

    try circuit.x(1);
    try circuit.x(4);
    try circuit.x(7);
}

fn parallel_sat_solver_diffuser(circuit: *QuantumCircuit) !void {
    try circuit.cx(0, 2);
    try circuit.cx(0, 5);

    try circuit.h(0);
    try circuit.h(3);
    try circuit.h(6);
    try circuit.x(0);
    try circuit.x(3);
    try circuit.x(6);
    try circuit.addGate(&ccz, &.{ 0, 3, 6 });
    try circuit.x(0);
    try circuit.x(3);
    try circuit.x(6);
    try circuit.h(0);
    try circuit.h(3);
    try circuit.h(6);

    try circuit.cx(0, 2);
    try circuit.cx(0, 5);
}
