const std = @import("std");
const panic = std.debug.panic;
const Vector = @import("vector.zig").Vector;

pub fn Matrix(comptime T: type) type {
    return struct {
        values: []T,
        n_rows: usize,
        n_cols: usize,

        const Self = @This();

        pub fn at(self: Self, row: usize, col: usize) usize {
            return self.n_cols * row + col;
        }

        pub fn colAt(self: Self, index: usize, buffer: Vector(T)) !Vector(T) {
            if (self.n_cols != buffer.values.len)
                return error.LengthsDontMatch;

            for (self.n_rows) |row| {
                buffer.values[row] = self.values[self.at(row, index)];
            }

            return buffer;
        }

        pub fn rowAt(self: Self, index: usize, buffer: Vector(T)) !Vector(T) {
            if (self.n_cols != buffer.values.len)
                return error.LengthsDontMatch;

            for (self.n_cols) |col| {
                buffer.values[col] = self.values[self.at(index, col)];
            }

            return buffer;
        }

        pub fn matrixMultiply(
            self: Self,
            other: Self,
            buffer: struct { v1: Vector(T), v2: Vector(T), m: Self },
        ) !Self {
            if (self.n_rows != other.n_cols)
                return error.LengthsDontMatch;

            for (self.n_rows) |row| {
                for (other.n_cols) |col| {
                    const row_v = try self.rowAt(row, buffer.v1);
                    const col_v = try other.colAt(col, buffer.v2);
                    buffer.m.valuesf[buffer.m.at(row, col)] = row_v.inner(col_v);
                }
            }
        }

        pub fn format(
            value: Self,
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
    };
}
