/// Helper (Windows): Make an int resource referencing the name of the resource.
///
/// - @param `offset` The offset into the collection of resource names
///
/// @returns Name of the resource
pub fn makeIntResourceA(comptime value: i32) [*:0]const u8 {
    const usize_value = if (value >= 0) value else @as(usize, @bitCast(@as(isize, value)));
    const temp: [*:0]const u8 = @ptrFromInt(usize_value);
    return temp;
}
