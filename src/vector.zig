const std = @import("std");
const Matrix = @import("matrix.zig").Matrix;
const Complex = @import("complex.zig");

values: []Complex,

const Vector = @This();

pub fn add(self: Vector, other: Vector, buffer: Vector) !Vector {
    if (self.values.len != other.values.len or self.values.len != buffer.values.len)
        return error.LengthsDontMatch;

    for (self.values, other.values, 0..) |a, b, i| {
        buffer.values[i] = a.add(b);
    }

    return buffer;
}

pub fn scale(self: Vector, scalar: Complex, buffer: Vector) !Vector {
    if (self.values.len != buffer.values.len)
        return error.LengthsDontMatch;

    for (0..self.values.len) |index| {
        buffer.values[index] = self.values[index].multiply(scalar);
    }

    return buffer;
}

pub fn inner(self: Vector, other: Vector) !Complex {
    if (self.values.len != other.values.len)
        return error.LengthsDontMatch;

    var sum = Complex.Zero;
    for (self.values, other.values) |a, b| {
        const value = a.conjugate().multiply(b);
        sum = sum.add(value);
    }

    return sum;
}

pub fn outer(self: Vector, other: Vector, buffer: Matrix(Complex)) !Matrix(Complex) {
    if (self.values.len != buffer.n_cols or other.values.len != buffer.n_rows)
        return error.LengthsDontMatch;

    for (self.values, 0..) |row_value, row| {
        for (other.values, 0..) |col_value, col| {
            const value = row_value.multiply(col_value.conjugate());
            buffer.values[buffer.at(row, col)] = value;
        }
    }

    return buffer;
}

pub fn tensor(self: Vector, other: Vector, buffer: Vector) !Vector {
    const len = self.values.len * other.values.len;
    if (len != buffer.values.len)
        return error.LengthsDontMatch;

    const n = other.values.len;
    for (self.values, 0..) |a, index_a| {
        for (other.values, 0..) |b, index_b| {
            const index = n * index_a + index_b;
            buffer.values[index] = a.multiply(b);
        }
    }
    
    return buffer;
}

pub fn conjugate(self: Vector, buffer: Vector) !Vector {
    if (self.values.len != buffer.values.len)
        return error.LengthsDontMatch;

    for (0..self.values.len) |index| {
        buffer.values[index] = self.values[index].conjugate();
    }

    return buffer;
}

pub fn format(
    value: Vector,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;

    if (std.mem.eql(u8, fmt, "|>")) {
        var buffer: [64]u8 = undefined;
        const size: usize = @intFromFloat(@log2(@as(f64, @floatFromInt(value.values.len))));

        var first = true;
        for (value.values, 0..) |a, index| {
            if (!std.math.approxEqAbs(f64, a.norm(), 0, 1e-9)) {
                toBinary(index, buffer[0..size]);
                if (first) {
                    first = false;
                    try writer.print("{}|{s}>", .{ a, buffer[0..size] });
                } else {
                    try writer.print(" + {}|{s}>", .{ a, buffer[0..size] });
                }
            }
        } 
    } else if(std.mem.eql(u8, fmt, "%")) {
        var buffer: [64]u8 = undefined;
        const size: usize = @intFromFloat(@log2(@as(f64, @floatFromInt(value.values.len))));

        var first = true;
        for (value.values, 0..) |a, index| {
            if (!std.math.approxEqAbs(f64, a.norm(), 0, 1e-9)) {
                toBinary(index, buffer[0..size]);
                if (first) {
                    first = false;
                    try writer.print("{d:.2}%|{s}>", .{ a.squaredNorm() * 100, buffer[0..size] });
                } else {
                    try writer.print(" + {d:.2}%|{s}>", .{ a.squaredNorm() * 100, buffer[0..size] });
                }
            }
        }
    } else {
        for (value.values) |a| {
            try writer.print("{any} ", .{a});
        }
    }
    try writer.print("\n", .{});
}

fn toBinary(number: usize, buffer: []u8) void {
    var shift: u32 = 1;
    for (0..buffer.len) |index| {
        const char: u8 = if (number & shift == 0) '0' else '1';
        buffer[index] = char;
        shift = shift << 1;
    }
    std.mem.reverse(u8, buffer);
}
