# Simple Debug
Simple Debug helps you set and unset breakpoints from within emacs that lldb can parse and set.

<img width="1048" alt="Screenshot 2022-10-16 at 22 44 17" src="https://user-images.githubusercontent.com/5260991/196059727-b72b25e0-13ad-4be8-8978-f553f5c3f88a.png">


## How does it work
Simple Debug creates a minor mode called "simple-debug" with `SiD` lighter. It adds itself to `c-mode-common-hook` so its invoked for C/C++ files. It binds `<F6>` key to `simple-debug-toggle-line-breakpoint` and `<F7>` key to `simple-debug-toggle-function-breakpoint`. This way pressing `<F6>` on any line creates a `line` breakpoint in the current file. Similarly the idea is that pressing `<F7>` anywhere in the body of a function creates a `function` breakpoint. At the moment function name needs to be selcted before pressig `<F7>`.

These breakpoints are written out into `.simple-debug.json` file in your project root directory (via `projectile-root-folder`). When you are ready to debug in lldb. You can import these using the provided python script;

`command script import /root/of/simple-debug/simple_debug_lldb_breakpoints.py`

You can also add this to your `.lldbinit` file to load any project `.simple-debug.json` files on start up (its also possible to create a project specific `.lldbinit` but its not the best practice).

## Getting started

To try this out first clone the repo and then run the following commands.

```
git clone https://github.com/abbaswasim/simple-debug.git && cd simple-debug
```

Open `simple-debug.el` in `emacs` and call `eval-buffer`. Now you can open any C/C++ file within your `projectile` project to add/remove breakpoints. Once done in emacs. Load your executable in lldb and load the python script to install all the breakpoints.

```
command script import /root/of/simple-debug/simple_debug_lldb_breakpoints.py
```

## Requirements
- Json
- Projectile

## Limitation
- At the moment after editing your source files. The debug marker moves fine but the actual breakpoint location doesn't change. This requires constant update to the breakpoint line numbers which has performance implications.
- Enabling and disabling the minor mode multiple times gets confused. Only one shot at the moment.
- Function breakpoints can only be used by selecting the function name cleanly. Ideally I would read the function name somehow from anywhere within its body.

## Wishlist
- Need a method to reset all breakpoints
- A method to update breakpoints according to the `overlays` in the source file
- Very complex for this usecase but maybe in the future migrate to using lldb syntax for the breakpoints itself
- Navigation of breakpoints accross the project to easily add/remove them
- Create an equivalent gdb script
