# Zig Native Window Library (ZNWL)

This project serves as a part of a larger project to create a game engine from scratch. However, I strive to keep this library abstracted from the game engine and more generic. The initial focus of features may be around getting a minimal product for the engine, but I plan to expand the library to be generic and easy to use for any purpose.

I am fairly new to Zig and it has been a few years since I last programmed in C/C++. With that in mind this project also serves as a learning tool for Zig, system programming, and open source.

I hope to keep all my projects as open source and community based as possible. Any tips, PRs, and overall help are more than welcome.

> ⚠️ Warn: This repo is currently exploratory and the API is subject to change with every merge into the main branch. To help with the volatile nature, this project will be split into a develop and a main branch.

## Goal

A native windowing library cross-compiling without any fuss or problems to Windows, Linux (X11 + Wayland), MacOS, iOS, and Android.

The library is written in pure Zig with the only non zig portions being APIs to native system libraries. There is nothing wrong with using GLFW and other related libraries, I just want to try something new. This library will start off basic and naïve and grow to be smart, easy to use, and full of features.

Hopefully this library will stay generic enough to be able to be used with most other libraries and projects like `Vulkan` and `ImGUI`.

**References**

- GLFW \(C\): https://www.glfw.org/docs/3.3/window_guide.html
- Winit (Rust): https://github.com/rust-windowing/winit
  - [windows::window](https://github.com/rust-windowing/winit/blob/4cd6877e8e19e7e1ba957a409394dca1af4afcdd/src/platform_impl/windows/window.rs#L432))
- CursorOption \(Rust\): https://docs.rs/cursor-icon/latest/cursor_icon/
- Notifications
  - Windows
    - Toast Notification in plain C: https://gist.github.com/valinet/3283c79ba35fc8f103c747c8adbb6b23
    - Win32 ToastNotificationManager: https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotificationmanager?view=winrt-26100


## TODO

- [ ] Fix keyboard input
- [ ] Add gamepad, controller, joystick input
