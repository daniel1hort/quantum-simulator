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

        pub fn copyFrom(self: *Self, other: Self) void {
            self.n_rows = other.n_rows;
            self.n_cols = other.n_cols;
            @memcpy(self.values[0..other.values.len], other.values);
        }

        pub fn colAt(self: Self, index: usize, buffer: Vector(T)) !Vector(T) {
            if (self.n_cols != buffer.values.len)
                return error.LengthsDontMatch;

            for (0..self.n_rows) |row| {
                buffer.values[row] = self.values[self.at(row, index)];
            }

            return buffer;
        }

        pub fn rowAt(self: Self, index: usize, buffer: Vector(T)) !Vector(T) {
            if (self.n_cols != buffer.values.len)
                return error.LengthsDontMatch;

            for (0..self.n_cols) |col| {
                buffer.values[col] = self.values[self.at(index, col)];
            }

            return buffer;
        }

        pub fn vectorMultiply(self: Self, other: Vector(T), buffer: Vector(T)) !Vector(T) {
            if (self.n_cols != other.values.len or other.values.len != buffer.values.len)
                return error.LengthsDontMatch;

            switch (@typeInfo(T)) {
                .ComptimeInt, .Int, .ComptimeFloat, .Float => {
                    for (0..self.n_rows) |row| {
                        var sum: T = 0;
                        for (0..self.n_cols, other.values) |col, x| {
                            const a = self.values[self.at(row, col)];
                            sum += a * x;
                        }
                        buffer[row] = sum;
                    }
                },
                .Struct => {
                    if (!std.meta.hasMethod(T, "add"))
                        panic("no method add", .{});
                    if (!std.meta.hasMethod(T, "multiply"))
                        panic("no method multiply", .{});

                    for (0..self.n_rows) |row| {
                        var sum = T.Zero;
                        for (0..self.n_cols, other.values) |col, x| {
                            const a = self.values[self.at(row, col)];
                            sum = sum.add(a.multiply(x));
                        }
                        buffer.values[row] = sum;
                    }
                },
                else => unreachable,
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

            for (0..self.n_rows) |row| {
                for (0..other.n_cols) |col| {
                    const row_v = try self.rowAt(row, buffer.v1);
                    const col_v = try other.colAt(col, buffer.v2);
                    buffer.m.values[buffer.m.at(row, col)] = try row_v.inner(col_v);
                }
            }

            return buffer.m;
        }

        pub fn tensor(self: Self, other: Self, buffer: Self) !Self {
            const match_rows = self.n_rows * other.n_rows == buffer.n_rows;
            const match_cols = self.n_cols * other.n_cols == buffer.n_cols;
            if (!match_cols or !match_rows)
                return error.LengthsDontMatch;

            const n = other.n_rows;
            const m = other.n_cols;

            switch (@typeInfo(T)) {
                .ComptimeInt, .Int, .ComptimeFloat, .Float => {
                    for (0..self.n_rows) |row_a| {
                        for (0..self.n_cols) |col_a| {
                            for (0..other.n_rows) |row_b| {
                                for (0..other.n_cols) |col_b| {
                                    const row = n * row_a + row_b;
                                    const col = m * col_a + col_b;
                                    const a = self.values[self.at(row_a, col_a)];
                                    const b = self.values[self.at(row_b, col_b)];
                                    buffer.values[buffer.at(row, col)] = a * b;
                                }
                            }
                        }
                    }
                },
                .Struct => {
                    if (!std.meta.hasMethod(T, "multiply"))
                        panic("no method multiply", .{});

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
                },
                else => unreachable,
            }

            return buffer;
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
