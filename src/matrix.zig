const std = @import("std");
const Vector = @import("vector.zig");
const Complex = @import("complex.zig");

values: []Complex,
n_rows: usize,
n_cols: usize,

const Matrix = @This();

pub fn at(self: Matrix, row: usize, col: usize) usize {
    return self.n_cols * row + col;
}

pub fn copyFrom(self: *Matrix, other: Matrix) void {
    self.n_rows = other.n_rows;
    self.n_cols = other.n_cols;
    @memcpy(self.values[0..other.values.len], other.values);
}

pub fn colAt(self: Matrix, index: usize, buffer: Vector) !Vector {
    if (self.n_cols != buffer.values.len)
        return error.LengthsDontMatch;

    for (0..self.n_rows) |row| {
        buffer.values[row] = self.values[self.at(row, index)];
    }

    return buffer;
}

pub fn rowAt(self: Matrix, index: usize, buffer: Vector) !Vector {
    if (self.n_cols != buffer.values.len)
        return error.LengthsDontMatch;

    for (0..self.n_cols) |col| {
        buffer.values[col] = self.values[self.at(index, col)];
    }

    return buffer;
}

pub fn add(self: Matrix, other: Matrix, buffer: Matrix) !Matrix {
    const size_0 = self.n_rows != other.n_rows or self.n_cols != other.n_cols;
    const size_1 = self.n_rows != buffer.n_rows or self.n_cols != buffer.n_cols;
    if (size_0 or size_1)
        return error.LengthsDontMatch;

    for (self.values, other.values, 0..) |a, b, index| {
        buffer.values[index] = a.add(b);
    }

    return buffer;
}

pub fn vectorMultiply(self: Matrix, other: Vector, buffer: Vector) !Vector {
    if (self.n_cols != other.values.len or other.values.len != buffer.values.len)
        return error.LengthsDontMatch;

    for (0..self.n_rows) |row| {
        var sum = Complex.Zero;
        for (0..self.n_cols, other.values) |col, x| {
            const a = self.values[self.at(row, col)];
            sum = sum.add(a.multiply(x));
        }
        buffer.values[row] = sum;
    }

    return buffer;
}

pub fn matrixMultiply(
    self: Matrix,
    other: Matrix,
    buffer: struct { v1: Vector, v2: Vector, m: Matrix },
) !Matrix {
    if (self.n_rows != other.n_cols)
        return error.LengthsDontMatch;

    const n = self.n_rows;
    for (0..n) |row| {
        for (0..n) |col| {
            var sum: Complex = Complex.Zero;

            for (0..n) |k| {
                const a = self.values[self.at(row, k)];
                const b = self.values[self.at(k, col)];
                sum = sum.add(a.multiply(b));
            }

            buffer.m.values[buffer.m.at(row, col)] = sum;
        }
    }

    return buffer.m;
}

pub fn tensor(self: Matrix, other: Matrix, buffer: Matrix) !Matrix {
    const match_rows = self.n_rows * other.n_rows == buffer.n_rows;
    const match_cols = self.n_cols * other.n_cols == buffer.n_cols;
    if (!match_cols or !match_rows)
        return error.LengthsDontMatch;

    const n = other.n_rows;
    const m = other.n_cols;
    for (0..self.n_rows) |row_a| {
        for (0..self.n_cols) |col_a| {
            for (0..other.n_rows) |row_b| {
                for (0..other.n_cols) |col_b| {
                    const row = n * row_a + row_b;
                    const col = m * col_a + col_b;
                    const a = self.values[self.at(row_a, col_a)];
                    const b = other.values[other.at(row_b, col_b)];
                    buffer.values[buffer.at(row, col)] = a.multiply(b);
                }
            }
        }
    }

    return buffer;
}

pub fn format(
    value: Matrix,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    for (0..value.n_rows) |row| {
        for (0..value.n_cols) |col| {
            try writer.print("{} ", .{value.values[value.at(row, col)]});
        }
        try writer.print("\n", .{});
    }
}
