const std = @import("std");

pub const Complex = packed struct {
    a: f64,
    b: f64,

    pub const epsilon = 1e-9;
    pub const Zero = Complex{ .a = 0, .b = 0 };

    pub fn equals(self: Complex, other: Complex) bool {
        return std.math.approxEqAbs(f64, self.a, other.a, epsilon) and std.math.approxEqAbs(f64, self.b, other.b, epsilon);
    }

    pub fn norm(self: Complex) f64 {
        return std.math.sqrt(self.a * self.a + self.b * self.b);
    }

    pub fn squaredNorm(self: Complex) f64 {
        return self.a * self.a + self.b * self.b;
    }

    pub fn negate(self: Complex) Complex {
        return .{
            .a = -self.a,
            .b = -self.b,
        };
    }

    pub fn conjugate(self: Complex) Complex {
        return .{
            .a = self.a,
            .b = -self.b,
        };
    }

    pub fn reciprocal(self: Complex) Complex {
        const den = self.a * self.a + self.b * self.b;
        return .{
            .a = self.a / den,
            .b = -self.b / den,
        };
    }

    pub fn sqrt(self: Complex) Complex {
        const sign = if (self.b < 0) @as(f64, -1.0) else @as(f64, 1.0);
        const norm_ = std.math.sqrt(self.a * self.a + self.b * self.b);
        return .{
            .a = std.math.sqrt(self.a + norm_) * std.math.sqrt1_2,
            .b = sign * std.math.sqrt(-self.a + norm_) * std.math.sqrt1_2,
        };
    }

    pub fn add(self: Complex, other: Complex) Complex {
        return .{
            .a = self.a + other.a,
            .b = self.b + other.b,
        };
    }

    pub fn multiply(self: Complex, other: Complex) Complex {
        return .{
            .a = self.a * other.a - self.b * other.b,
            .b = self.a * other.b + self.b * other.a,
        };
    }

    pub fn divide(self: Complex, other: Complex) Complex {
        return self.multiply(other.reciprocal());
    }

    pub fn format(
        value: Complex,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        if (!std.math.approxEqAbs(f64, value.a, 0, epsilon) and std.math.approxEqAbs(f64, value.b, 0, epsilon)) {
            try writer.print("{d:.6}", .{value.a});
        } else if (std.math.approxEqAbs(f64, value.a, 0, epsilon) and !std.math.approxEqAbs(f64, value.b, 0, epsilon)) {
            try writer.print("{d:.6}i", .{value.b});
        } else if (!std.math.approxEqAbs(f64, value.a, 0, epsilon) and !std.math.approxEqAbs(f64, value.b, 0, epsilon)) {
            const sign: u8 = if (std.math.sign(value.b) == -1) '-' else '+';
            try writer.print("{d:.6} {c} {d:.6}i", .{ value.a, sign, @abs(value.b) });
        } else {
            try writer.print("0", .{});
        }
    }
};

test "sqrt of complex number" {
    const numbers = [_]Complex{
        Complex.Zero,
        .{ .a = 4, .b = 0 },
        .{ .a = -4, .b = 0 },
        .{ .a = 0, .b = 4 },
        .{ .a = 0, .b = -4 },
        .{ .a = -2, .b = 4 },
    };

    for (numbers) |number| {
        const z_sqrt = number.sqrt();
        const z_res = z_sqrt.multiply(z_sqrt);
        try std.testing.expect(number.equals(z_res));
    }
}
