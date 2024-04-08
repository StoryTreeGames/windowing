const std = @import("std");

/// Helper (Windows): Make an int resource referencing the name of the resource.
///
/// - @param `offset` The offset into the collection of resource names
///
/// @returns Name of the resource
pub fn makeIntResourceA(comptime value: usize) [*:0]const u8 {
    return @ptrFromInt(value);
}

/// Helper (Windows): Make an int resource referencing the name of the resource.
///
/// - @param `offset` The offset into the collection of resource names
///
/// @returns Name of the resource
pub fn makeIntResourceW(comptime value: usize) [*:0]align(1) const u16 {
    return @ptrFromInt(value);
}
