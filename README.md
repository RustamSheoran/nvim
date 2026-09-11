# My LazyVim + Competitive Programming Setup

This is my personal Neovim configuration based on [LazyVim](https://github.com/LazyVim/LazyVim), completely customized for high-speed Competitive Programming.

## How to restore this setup on a new system

If you are setting this up on a new machine or re-installing your OS (like Omarchy) after a few months, follow these steps:

1. **Prerequisites**: Make sure Neovim (>=0.10) and a C++ compiler (`g++`) are installed on your system.
2. **Clone this repo**:
   ```bash
   git clone <your-github-repo-url> ~/.config/nvim
   ```
3. **Start Neovim**: Open `nvim`. LazyVim will automatically download all plugins, formatters, and LSP servers.
4. **Browser Extensions**:
   - Install the **Competitive Companion** browser extension.
   - Install the **cph-submit** browser extension.
   - *Note: You do NOT need the Node.js `cph` server or VS Code anymore! The entire CPH submission server runs natively inside Neovim.*

## Competitive Programming Workflow

- Open any C++ file or start Neovim in your `~/cp/` directory.
- Click the **green plus button** in Competitive Companion on any problem page.
- Neovim will automatically create the `problem.cpp` file from your template and download all testcases.
- Write your code.
- Press `<leader>rr` to run the sample testcases.
- Press `<leader>rs` to run a fast syntax check and instantly send your code to the `cph-submit` extension for submission.

## Note on Omarchy OS

This Neovim configuration is entirely independent of the Omarchy OS configuration system. Pushing this folder to GitHub is all you need to keep your C++ and CP configurations safe. You won't lose your Neovim configurations during an `omarchy update`.
