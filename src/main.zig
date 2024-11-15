const std = @import("std");
const Complex = @import("complex.zig").Complex;
const Vector = @import("vector.zig").Vector(Complex);
const Matrix = @import("matrix.zig").Matrix(Complex);

pub fn U(theta: f64, phi: f64, lambda: f64) [2][2]Complex {
    return .{
        .{
            .{
                .a = @cos(theta * 0.5),
                .b = 0,
            },
            .{
                .a = -@cos(lambda) * @sin(theta * 0.5),
                .b = -@sin(lambda) * @sin(theta * 0.5),
            },
        },
        .{
            .{
                .a = @cos(phi) * @sin(theta * 0.5),
                .b = @sin(phi) * @sin(theta * 0.5),
            },
            .{
                .a = @cos(phi + lambda) * @cos(theta * 0.5),
                .b = @sin(phi + lambda) * @cos(theta * 0.5),
            },
        },
    };
}

pub fn main() !void {
    const ZeroQ: [2]Complex = .{
        .{ .a = 1.0, .b = 0.0 },
        .{ .a = 0.0, .b = 0.0 },
    };

    const H = U(std.math.pi * 0.5, 0, std.math.pi);
    const X = U(std.math.pi, 0, std.math.pi);

    var result: [2]Complex = undefined;

    for (H, 0..) |column, i| {
        for (column, ZeroQ) |z1, z2| {
            result[i] = result[i].add(z1.multiply(z2));
        }
    }

    printState(result);

    result[0] = Complex.Zero;
    result[1] = Complex.Zero;

    for (X, 0..) |column, i| {
        for (column, ZeroQ) |z1, z2| {
            result[i] = result[i].add(z1.multiply(z2));
        }
    }

    printState(result);

    const OneQ = result;
    result[0] = Complex.Zero;
    result[1] = Complex.Zero;

    for (X, 0..) |column, i| {
        for (column, OneQ) |z1, z2| {
            result[i] = result[i].add(z1.multiply(z2));
        }
    }

    printState(result);

    const v_values = [_]Complex{
        .{ .a = 1, .b = 1 },
        .{ .a = 2, .b = 0 },
        .{ .a = 3, .b = 0 },
    };
    var buffer_v_values: [v_values.len]Complex = undefined;
    var buffer_m_values: [v_values.len * v_values.len]Complex = undefined;
    const v1: Vector = .{ .values = @constCast(&v_values) };
    const v2: Vector = .{ .values = @constCast(&v_values) };
    const buffer_v: Vector = .{ .values = &buffer_v_values };
    const buffer_m: Matrix = .{
        .values = &buffer_m_values,
        .n_rows = v_values.len,
        .n_cols = v_values.len,
    };

    std.debug.print("v1 = {}\n", .{v1});

    const sum = try Vector.add(v1, v2, buffer_v);
    std.debug.print("v1 + v1 = {}\n", .{sum});

    const scalar: Complex = .{ .a = 2, .b = 0 };
    const scaled = try Vector.scale(v1, scalar, buffer_v);
    std.debug.print("v1 * {} = {}\n", .{ scalar, scaled });

    const conjugate = try Vector.conjugate(v1, buffer_v);
    std.debug.print("v1* = {}\n", .{conjugate});

    const inner = try Vector.inner(v1, v2);
    std.debug.print("<v1|v1> = {}\n", .{inner});

    const outer = try Vector.outer(v1, v1, buffer_m);
    std.debug.print("|v1xv1| = \n{}", .{outer});
}

fn printState(qubit: [2]Complex) void {
    std.debug.print("state: ({}, {})\n", .{
        qubit[0],
        qubit[1],
    });

    std.debug.print("probabilities: ({d:.6}, {d:.6})\n\n", .{
        qubit[0].squaredNorm(),
        qubit[1].squaredNorm(),
    });
}
