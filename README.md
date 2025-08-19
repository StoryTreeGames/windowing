# StoryTree Core

This project serves as a part of a larger project to create a game engine from scratch. However, I strive to keep this library abstracted from the game engine and more generic. The initial focus of features may be around getting a minimal product for the engine, but I plan to expand the library to be generic and easy to use for any purpose.

Any tips, PRs, and overall help are more than welcome.

> ⚠️ Warn: This repo is currently exploratory and the API is subject to change with every merge into the main branch
> To help with the volatile nature, this project will be split into a develop and a main branch.

## Goal

A native windowing library cross-compiling without any fuss or problems to Windows, Linux (X11 + Wayland), MacOS, iOS, and Android. Supported platforms will include Windows, Linux (X11 + Wayland), MacOS; and will be expanded to Web, IOS, and Android in the future.

The library is written in as much pure Zig as possible to provide an easy to use API with minimal dependencies. There is nothing wrong with using GLFW and other related libraries, I just want to try to create something new. This library will start off basic and naïve and grow to be intuitive, easy to use, and full of platform specific opt in features.

Hopefully this library will remain generic enough to be able to be used with most other libraries and projects like `Vulkan` and `ImGUI`.

## Requirements

- **Linux**
  - Packages: `wayland-protocols`, `libwayland-dev` (or a varant that provides wayland-scanner)

## TODO

- [ ] Windows
  - [x] Queue the events and pop them when polling instead of having them instantly being sent to app handler
  - [ ] Finish keyboard input to support dead keys
  - [x] Query key
  - [ ] Query Mouse
  - [ ] Add gamepad, controller, joystick input
  - [ ] Audio
  - [ ] System Tray
  - [ ] Owner Drawn menu bar for system theme colors?
    - This can be difficult and error prone. Plain white background with black text should work for now.

- [ ] Wayland
  - [ ] Basic window creation
  - [ ] Event listening and handling
  - [ ] Query keys and input state
  - [ ] Audio
  - [ ] Notifications
  - [ ] System Tray
  - [ ] Title Bar + Menu

- [ ] X11
  - [ ] Basic window creation
  - [ ] Event listening and handling
  - [ ] Query keys and input state
  - [ ] Audio
  - [ ] Notifications
  - [ ] System Tray
  - [ ] Title Bar + Menu

- [ ] MacOS
  - [ ] Basic window creation
  - [ ] Event listening and handling
  - [ ] Query keys and input state
  - [ ] Audio
  - [ ] Notifications
  - [ ] System Tray
  - [ ] Title Bar + Menu

## References

- GLFW \(C\): https://www.glfw.org/docs/3.3/window_guide.html
- Winit (Rust): https://github.com/rust-windowing/winit
  - [windows::window](https://github.com/rust-windowing/winit/blob/4cd6877e8e19e7e1ba957a409394dca1af4afcdd/src/platform_impl/windows/window.rs#L432))
- CursorOption \(Rust\): https://docs.rs/cursor-icon/latest/cursor_icon/
- Notifications
  - Windows
    - Toast Notification in plain C: https://gist.github.com/valinet/3283c79ba35fc8f103c747c8adbb6b23
    - Win32 ToastNotificationManager: https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotificationmanager?view=winrt-26100
