const wam = @import("win32").ui.windows_and_messaging;
const IconType = @import("../icon.zig").IconType;

/// Helper (Windows): Make an int resource referencing the name of the resource.
///
/// - @param `offset` The offset into the collection of resource names
///
/// @returns Name of the resource
fn makeIntResourceW(comptime value: usize) [*:0]align(1) const u16 {
    return @ptrFromInt(value);
}

pub fn iconToResource(icon: IconType) [*:0]align(1) const u16 {
    return switch (icon) {
        .default => wam.IDI_APPLICATION,
        .@"error" => makeIntResourceW(wam.IDI_ERROR),
        .question => wam.IDI_QUESTION,
        .warning => makeIntResourceW(wam.IDI_WARNING),
        .information => makeIntResourceW(wam.IDI_INFORMATION),
        .security => wam.IDI_SHIELD,
    };
}
