# Zig Native Window Library (ZNWL)

This project is in inspiration of a larger project that I am planning to work toward. However, one of the foundational pieces is the ability to create windows on natively on different devices/systems. That is the goal of this library, a focus on creating
native windows and managing their state and events.

The goal is to get the library cross-compiling without any fuss or problems to Windows, Linux (X11 + Wayland), MacOs, iOS, and Android.

I am fairly new to Zig and it has been a few years since I last programmed in C this project also serves as a learning tool for Zig, system programming, and open source.

I hope to keep all my projects as open source and community based as possible. Any tips, PRs, and overall help are more than welcome.

> ⚠️ Warn: This repo is currently exploratory and the API is subject to change with every merge into the main branch. To help with the volatile nature, this project will be split into a develop and a main branch.

## Goal

The goal of this library is to write as pure of a zig library as possible to move away from GLFW and it's idioms. There
is nothing wrong with using GLFW, I just want to try something new. This project is pulling inspiration from multiple
other libraries and their API. This library will start off basic and naïve and grow to be smart, easy to use, and full
of features.

Hopefully this library will stay generic to be able to be used with most other libraries and projects. Some other project ideas include: game engines and GUI applications.

**References**

- [GLFW (C)](https://www.glfw.org/docs/3.3/window_guide.html)
- [Winit (Rust)](https://github.com/rust-windowing/winit)
