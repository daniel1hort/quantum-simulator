const std = @import("std");
const Allocator = std.mem.Allocator;
const Complex = @import("complex.zig").Complex;
const Matrix = @import("matrix.zig").Matrix(Complex);
const Vector = @import("vector.zig").Vector(Complex);

pub const Gate = struct {
    matrix: *const Matrix,
    qubits: []usize,
    time: usize = 0,
};

pub const QuantumCircuit = struct {
    allocator: Allocator,
    q_reg: Vector,
    gates: std.ArrayList(Gate),
    times: []usize,
    permutations: []usize,

    pub fn init(allocator: Allocator, q_num: usize) !QuantumCircuit {
        const reg_size = std.math.pow(usize, 2, q_num);
        const reg_b = try allocator.alloc(Complex, reg_size);
        @memset(reg_b, Complex.Zero);
        reg_b[0].a = 1.0;
        const q_reg = Vector{ .values = reg_b };

        const times = try allocator.alloc(usize, q_num);
        @memset(times, 0);
        const permutations = try allocator.alloc(usize, q_num);
        for (0..q_num) |index| {
            permutations[index] = index;
        }

        const gates = std.ArrayList(Gate).init(allocator);
        return .{
            .allocator = allocator,
            .q_reg = q_reg,
            .gates = gates,
            .times = times,
            .permutations = permutations,
        };
    }

    pub fn deinit(self: QuantumCircuit) void {
        self.allocator.free(self.q_reg.values);
        self.allocator.free(self.times);
        self.allocator.free(self.permutations);
        for (self.gates.items) |*gate| {
            self.allocator.free(gate.qubits);
        }
        self.gates.deinit();
    }

    pub fn x(self: *QuantumCircuit, qubit: usize) !void {
        const qubits = try self.allocator.alloc(usize, 1);
        qubits[0] = qubit;
        self.times[qubit] += 1;
        const gate = Gate{
            .matrix = &standard_matrices[1],
            .qubits = qubits,
            .time = self.times[qubit],
        };
        try self.gates.append(gate);
    }

    pub fn h(self: *QuantumCircuit, qubit: usize) !void {
        const qubits = try self.allocator.alloc(usize, 1);
        qubits[0] = qubit;
        self.times[qubit] += 1;
        const gate = Gate{
            .matrix = &standard_matrices[2],
            .qubits = qubits,
            .time = self.times[qubit],
        };
        try self.gates.append(gate);
    }

    pub fn cx(self: *QuantumCircuit, control: usize, target: usize) !void {
        const qubits = try self.allocator.alloc(usize, 2);
        qubits[0] = control;
        qubits[1] = target;
        const time = @max(self.times[control], self.times[target]) + 1;
        self.times[control] = time;
        self.times[target] = time;
        const gate = Gate{
            .matrix = &standard_matrices[3],
            .qubits = qubits,
            .time = time,
        };
        try self.gates.append(gate);
    }

    pub fn swap(self: *QuantumCircuit, a: usize, b: usize) !void {
        const qubits = try self.allocator.alloc(usize, 2);
        qubits[0] = a;
        qubits[1] = b;
        const time = @max(self.times[a], self.times[b]) + 1;
        self.times[a] = time;
        self.times[b] = time;
        const gate = Gate{
            .matrix = &standard_matrices[4],
            .qubits = qubits,
            .time = time,
        };
        try self.gates.append(gate);
    }

    pub fn barrier(self: *QuantumCircuit) void {
        const time = std.mem.max(usize, self.times);
        @memset(self.times, time);
    }

    pub fn run(self: *QuantumCircuit) !void {
        const buffer_len = self.q_reg.values.len;
        const _buffer = try self.allocator.alloc(Complex, buffer_len);
        defer self.allocator.free(_buffer);
        const buffer = Vector{ .values = _buffer };

        const depth = std.mem.max(usize, self.times);
        for (1..depth + 1) |time| {
            const matrix = try self.tensor(time);
            defer self.allocator.free(matrix.values);

            _ = try matrix.vectorMultiply(self.q_reg, buffer);
            @memcpy(self.q_reg.values, _buffer);
        }
    }

    fn tensor(self: QuantumCircuit, time: usize) !Matrix {
        // get gates at time
        var gates = std.ArrayList(Gate).init(self.allocator);
        defer gates.deinit();
        for (self.gates.items) |gate| {
            if (gate.time == time)
                try gates.append(gate);
        }

        // order gates and add identities
        var matrices = std.ArrayList(*const Matrix).init(self.allocator);
        defer matrices.deinit();
        var qubit: usize = 0;
        while (qubit < self.times.len) : (qubit += 1) {
            const matrix = blk: {
                for (gates.items) |gate| {
                    if (std.mem.indexOfScalar(usize, gate.qubits, qubit)) |_| {
                        qubit += gate.qubits.len - 1;
                        break :blk gate.matrix;
                    }
                }
                break :blk null;
            } orelse &standard_matrices[0];

            try matrices.append(matrix);
        }

        const buffer_len = self.q_reg.values.len * self.q_reg.values.len;
        var _buffer = try self.allocator.alloc(Complex, buffer_len);
        defer self.allocator.free(_buffer);
        const _current = try self.allocator.alloc(Complex, buffer_len);

        var current = std.mem.zeroes(Matrix);
        current.values = _current;
        current.copyFrom(matrices.items[0].*);

        for (matrices.items[1..]) |next| {
            const n_rows = current.n_rows * next.n_rows;
            const n_cols = current.n_cols * next.n_cols;
            const tensor_len = n_rows * n_cols;

            const buffer = Matrix{
                .values = _buffer[0..tensor_len],
                .n_rows = n_rows,
                .n_cols = n_cols,
            };

            _ = try current.tensor(next.*, buffer);
            current.copyFrom(buffer);
        }

        return current;
    }
};

const standard_matrices: [5]Matrix = .{
    .{
        .values = @constCast(&U(0, 0, 0)),
        .n_rows = 2,
        .n_cols = 2,
    },
    .{
        .values = @constCast(&U(std.math.pi, 0, std.math.pi)),
        .n_rows = 2,
        .n_cols = 2,
    },
    .{
        .values = @constCast(&U(std.math.pi * 0.5, 0, std.math.pi)),
        .n_rows = 2,
        .n_cols = 2,
    },
    .{
        .values = @constCast(&[16]Complex{
            .{ .a = 1, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 1, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 1, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 1, .b = 0 },
            .{ .a = 0, .b = 0 },
        }),
        .n_rows = 4,
        .n_cols = 4,
    },
    .{
        .values = @constCast(&[16]Complex{
            .{ .a = 1, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 1, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 1, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 0, .b = 0 },
            .{ .a = 1, .b = 0 },
        }),
        .n_rows = 4,
        .n_cols = 4,
    },
};

fn U(theta: f64, phi: f64, lambda: f64) [4]Complex {
    return .{
        .{
            .a = @cos(theta * 0.5),
            .b = 0,
        },
        .{
            .a = -@cos(lambda) * @sin(theta * 0.5),
            .b = -@sin(lambda) * @sin(theta * 0.5),
        },
        .{
            .a = @cos(phi) * @sin(theta * 0.5),
            .b = @sin(phi) * @sin(theta * 0.5),
        },
        .{
            .a = @cos(phi + lambda) * @cos(theta * 0.5),
            .b = @sin(phi + lambda) * @cos(theta * 0.5),
        },
    };
}
