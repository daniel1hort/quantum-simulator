const std = @import("std");
const Allocator = std.mem.Allocator;
const Complex = @import("complex.zig");
const Matrix = @import("matrix.zig");
const Vector = @import("vector.zig");

pub const Gate = struct {
    matrix: *const Matrix,
    qubits: []usize,
    time: usize = 0,

    pub fn controlled(allocator: Allocator, matrix: Matrix) !Matrix {
        const size: usize = @intFromFloat(@log2(@as(f64, @floatFromInt(matrix.n_rows))));

        const dimension = std.math.pow(usize, 2, size + 1);
        const buffer_len = dimension * dimension;
        const _buffer_0 = try allocator.alloc(Complex, buffer_len);
        defer allocator.free(_buffer_0);
        const _buffer_1 = try allocator.alloc(Complex, buffer_len);
        defer allocator.free(_buffer_1);
        const _current = try allocator.alloc(Complex, buffer_len);

        var buffer_0: Matrix = undefined;
        var buffer_1: Matrix = undefined;
        var current = std.mem.zeroes(Matrix);
        current.values = _current;
        current.copyFrom(rho_0);

        for (0..size) |_| {
            const next = &identity;
            const n_rows = current.n_rows * next.n_rows;
            const n_cols = current.n_cols * next.n_cols;
            const tensor_len = n_rows * n_cols;

            buffer_0.values = _buffer_0[0..tensor_len];
            buffer_0.n_rows = n_rows;
            buffer_0.n_cols = n_cols;

            _ = try current.tensor(next.*, buffer_0);
            current.copyFrom(buffer_0);
        }

        current.copyFrom(rho_1);
        buffer_1.values = _buffer_1;
        buffer_1.n_rows = dimension;
        buffer_1.n_cols = dimension;
        _ = try current.tensor(matrix, buffer_1);

        current.n_rows = dimension;
        current.n_cols = dimension;
        _ = try buffer_0.add(buffer_1, current);

        return current;
    }
};

pub const QuantumCircuit = struct {
    allocator: Allocator,
    q_reg: Vector,
    gates: std.ArrayList(Gate),
    times: []usize,
    permutation: []usize,

    pub fn init(allocator: Allocator, q_num: usize) !QuantumCircuit {
        const reg_size = std.math.pow(usize, 2, q_num);
        const reg_b = try allocator.alloc(Complex, reg_size);
        @memset(reg_b, Complex.Zero);
        reg_b[0].a = 1.0;
        const q_reg = Vector{ .values = reg_b };

        const times = try allocator.alloc(usize, q_num);
        @memset(times, 0);
        const permutation = try allocator.alloc(usize, q_num);
        for (0..q_num) |index| {
            permutation[index] = index;
        }

        const gates = std.ArrayList(Gate).init(allocator);
        return .{
            .allocator = allocator,
            .q_reg = q_reg,
            .gates = gates,
            .times = times,
            .permutation = permutation,
        };
    }

    pub fn deinit(self: QuantumCircuit) void {
        self.allocator.free(self.q_reg.values);
        self.allocator.free(self.times);
        self.allocator.free(self.permutation);
        for (self.gates.items) |*gate| {
            self.allocator.free(gate.qubits);
        }
        self.gates.deinit();
    }

    pub fn x(self: *QuantumCircuit, qubit: usize) !void {
        const qubits = [_]usize{qubit};
        const matrix = &pauli_x;
        try self.addGate(matrix, &qubits);
    }

    pub fn z(self: *QuantumCircuit, qubit: usize) !void {
        const qubits = [_]usize{qubit};
        const matrix = &pauli_z;
        try self.addGate(matrix, &qubits);
    }

    pub fn h(self: *QuantumCircuit, qubit: usize) !void {
        const qubits = [_]usize{qubit};
        const matrix = &hadamard;
        try self.addGate(matrix, &qubits);
    }

    pub fn cx(self: *QuantumCircuit, control: usize, target: usize) !void {
        const qubits = [_]usize{ control, target };
        const matrix = &controlled_not;
        try self.addGate(matrix, &qubits);
    }

    pub fn swap(self: *QuantumCircuit, a: usize, b: usize) !void {
        const qubits = [_]usize{ a, b };
        const matrix = &swap_gate;
        try self.addGate(matrix, &qubits);
    }

    pub fn addGate(self: *QuantumCircuit, matrix: *const Matrix, qubits: []const usize) !void {
        const _qubits = try self.allocator.alloc(usize, qubits.len);
        @memcpy(_qubits, qubits);

        if (_qubits.len > 1) {
            try self.addSwapGates(_qubits);
        } else {
            const pos = std.mem.indexOfScalar(
                usize,
                self.permutation,
                _qubits[0],
            ).?;
            _qubits[0] = pos;
        }

        const time = self.maxTime(_qubits) + 1;
        for (_qubits) |qubit| {
            self.times[qubit] = time;
        }

        const gate = Gate{
            .matrix = matrix,
            .qubits = _qubits,
            .time = time,
        };
        try self.gates.append(gate);
    }

    fn intermediateSwap(self: *QuantumCircuit, a: usize, b: usize) !void {
        const qubits = try self.allocator.alloc(usize, 2);
        qubits[0] = a;
        qubits[1] = b;

        const time = @max(self.times[a], self.times[b]) + 1;
        self.times[a] = time;
        self.times[b] = time;
        const gate = Gate{
            .matrix = &swap_gate,
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
        try self.reorderQubits();
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
            } orelse &identity;

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

    fn firstQubitPosition(self: QuantumCircuit, qubits: []usize) usize {
        if (self.permutation.len == 1)
            return 0;

        const head = qubits[0];
        const tail = qubits[1..];
        const head_pos = std.mem.indexOfScalar(
            usize,
            self.permutation,
            head,
        ).?;
        const tail_pos = std.mem.indexOfAny(
            usize,
            self.permutation,
            tail,
        ).?;
        return @min(head_pos, tail_pos);
    }

    fn addSwapGates(self: *QuantumCircuit, qubits: []usize) !void {
        const desired_pos = self.firstQubitPosition(qubits);

        for (qubits, 0..) |qubit, offset| {
            const start = std.mem.indexOfScalar(
                usize,
                self.permutation,
                qubit,
            ).?;
            const end = desired_pos + offset;
            var pos = start;

            while (pos > end) : (pos -= 1) {
                try self.intermediateSwap(pos - 1, pos);
                swapValues(&self.permutation[pos - 1], &self.permutation[pos]);
            }
            qubits[offset] = end;
        }
    }

    pub fn reorderQubits(self: *QuantumCircuit) !void {
        const permutation = try self.allocator.alloc(usize, self.permutation.len);
        defer self.allocator.free(permutation);
        for (0..permutation.len) |index| {
            permutation[index] = index;
        }
        try self.addSwapGates(permutation);
    }

    fn maxTime(self: QuantumCircuit, qubits: []usize) usize {
        var max: usize = 0;
        for (qubits) |qubit| {
            max = @max(max, self.times[qubit]);
        }
        return max;
    }
};

fn swapValues(a: anytype, b: @TypeOf(a)) void {
    const aux: @TypeOf(a.*) = a.*;
    a.* = b.*;
    b.* = aux;
}

pub const identity = Matrix{
    .values = @constCast(&U(0, 0, 0)),
    .n_rows = 2,
    .n_cols = 2,
};
pub const pauli_x = Matrix{
    .values = @constCast(&U(std.math.pi, 0, std.math.pi)),
    .n_rows = 2,
    .n_cols = 2,
};
pub const pauli_z = Matrix{
    .values = @constCast(&P(std.math.pi)),
    .n_rows = 2,
    .n_cols = 2,
};
pub const hadamard = Matrix{
    .values = @constCast(&U(std.math.pi * 0.5, 0, std.math.pi)),
    .n_rows = 2,
    .n_cols = 2,
};
pub const controlled_not = Matrix{
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
};
pub const swap_gate = Matrix{
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
};
pub const rho_0 = Matrix{
    .values = @constCast(&[4]Complex{
        .{ .a = 1, .b = 0 },
        .{ .a = 0, .b = 0 },
        .{ .a = 0, .b = 0 },
        .{ .a = 0, .b = 0 },
    }),
    .n_rows = 2,
    .n_cols = 2,
};
pub const rho_1 = Matrix{
    .values = @constCast(&[4]Complex{
        .{ .a = 0, .b = 0 },
        .{ .a = 0, .b = 0 },
        .{ .a = 0, .b = 0 },
        .{ .a = 1, .b = 0 },
    }),
    .n_rows = 2,
    .n_cols = 2,
};

pub fn U(theta: f64, phi: f64, lambda: f64) [4]Complex {
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

pub fn P(alpha: f64) [4]Complex {
    return .{
        .{ .a = 1, .b = 0 },
        .{ .a = 0, .b = 0 },
        .{ .a = 0, .b = 0 },
        .{ .a = @cos(alpha), .b = @sin(alpha) },
    };
}
