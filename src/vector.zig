const std = @import("std");
const panic = std.debug.panic;
const Matrix = @import("matrix.zig").Matrix;

pub fn Vector(comptime T: type) type {
    return struct {
        values: []T,

        const Self = @This();

        pub fn add(self: Self, other: Self, buffer: Self) !Self {
            if (self.values.len != other.values.len or self.values.len != buffer.values.len)
                return error.LengthsDontMatch;

            switch (@typeInfo(T)) {
                .ComptimeInt, .Int, .ComptimeFloat, .Float => {
                    for (self.values, other.values, 0..) |a, b, i| {
                        buffer.values[i] = a + b;
                    }
                },
                .Struct => {
                    if (!std.meta.hasMethod(T, "add"))
                        panic("no method add", .{});

                    for (self.values, other.values, 0..) |a, b, i| {
                        buffer.values[i] = a.add(b);
                    }
                },
                else => unreachable,
            }

            return buffer;
        }

        pub fn scale(self: Self, scalar: T, buffer: Self) !Self {
            if (self.values.len != buffer.values.len)
                return error.LengthsDontMatch;

            switch (@typeInfo(T)) {
                .ComptimeInt, .Int, .ComptimeFloat, .Float => {
                    for (0..self.values.len) |index| {
                        buffer.values[index] = self.values[index] * scalar;
                    }
                },
                .Struct => {
                    if (!std.meta.hasMethod(T, "multiply"))
                        panic("no method multiply", .{});

                    for (0..self.values.len) |index| {
                        buffer.values[index] = self.values[index].multiply(scalar);
                    }
                },
                else => unreachable,
            }

            return buffer;
        }

        pub fn inner(self: Self, other: Self) !T {
            if (self.values.len != other.values.len)
                return error.LengthsDontMatch;

            var sum: T = undefined;
            switch (@typeInfo(T)) {
                .ComptimeInt, .Int, .ComptimeFloat, .Float => {
                    sum = 0;
                    for (self.values, other.values) |a, b| {
                        const value = a * b;
                        sum += value;
                    }
                },
                .Struct => {
                    sum = T.Zero;
                    if (!std.meta.hasMethod(T, "add"))
                        panic("no method add", .{});
                    if (!std.meta.hasMethod(T, "multiply"))
                        panic("no method multiply", .{});
                    const has_conjugate = std.meta.hasMethod(T, "conjugate");

                    for (self.values, other.values) |a, b| {
                        const value = if (has_conjugate)
                            a.conjugate().multiply(b)
                        else
                            a.multiply(b);

                        sum = sum.add(value);
                    }
                },
                else => unreachable,
            }

            return sum;
        }

        pub fn outer(self: Self, other: Self, buffer: Matrix(T)) !Matrix(T) {
            if (self.values.len != buffer.n_cols or other.values.len != buffer.n_rows)
                return error.LengthsDontMatch;

            switch (@typeInfo(T)) {
                .ComptimeInt, .Int, .ComptimeFloat, .Float => {
                    for (self.values, 0..) |row_value, row| {
                        for (other.values, 0..) |col_value, col| {
                            buffer.values[buffer.at(row, col)] = row_value * col_value;
                        }
                    }
                },
                .Struct => {
                    if (!std.meta.hasMethod(T, "multiply"))
                        panic("no method multiply", .{});
                    const has_conjugate = std.meta.hasMethod(T, "conjugate");

                    for (self.values, 0..) |row_value, row| {
                        for (other.values, 0..) |col_value, col| {
                            const value = if (has_conjugate)
                                row_value.multiply(col_value.conjugate())
                            else
                                row_value.multiply(col_value);

                            buffer.values[buffer.at(row, col)] = value;
                        }
                    }
                },
                else => unreachable,
            }

            return buffer;
        }

        pub fn tensor(self: Self, other: Self, buffer: Self) !Self {
            const len = self.values.len * other.values.len;
            if (len != buffer.values.len)
                return error.LengthsDontMatch;

            const n = other.values.len;
            switch (@typeInfo(T)) {
                .ComptimeInt, .Int, .ComptimeFloat, .Float => {
                    for (self.values, 0..) |a, index_a| {
                        for (other.values, 0..) |b, index_b| {
                            const index = n * index_a + index_b;
                            buffer.values[index] = a * b;
                        }
                    }
                },
                .Struct => {
                    if (!std.meta.hasMethod(T, "multiply"))
                        panic("no method multiply", .{});

                    for (self.values, 0..) |a, index_a| {
                        for (other.values, 0..) |b, index_b| {
                            const index = n * index_a + index_b;
                            buffer.values[index] = a.multiply(b);
                        }
                    }
                },
                else => unreachable,
            }

            return buffer;
        }

        pub fn conjugate(self: Self, buffer: Self) !Self {
            if (self.values.len != buffer.values.len)
                return error.LengthsDontMatch;

            switch (@typeInfo(T)) {
                .Struct => {
                    const has_conjugate = std.meta.hasMethod(T, "conjugate");

                    if (has_conjugate) {
                        for (0..self.values.len) |index| {
                            buffer.values[index] = self.values[index].conjugate();
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

            for (value.values) |a| {
                try writer.print("{any} ", .{a});
            }
            try writer.print("\n", .{});
        }
    };
}
