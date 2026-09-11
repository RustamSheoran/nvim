# My LazyVim + Competitive Programming Setup

This is my personal Neovim configuration based on [LazyVim](https://github.com/LazyVim/LazyVim). I've heavily customized it to create a blazing-fast, terminal-based competitive programming workflow.

If you're coming from VS Code and miss the seamless experience of the CPH (Competitive Programming Helper) extension, this setup is for you. We've built a native Lua HTTP server right into Neovim that entirely replaces the need for VS Code or any bulky Node.js background servers. 

## What You Need

To get the full one-click fetch and submit experience, you need to install two browser extensions:
1. **[Competitive Companion](https://github.com/jmerle/competitive-companion)** (often just called CPH) - Parses the problem statement and test cases from the website.
2. **[cph-submit](https://github.com/agrawal-d/cph-submit)** - Automates submitting your code directly from the editor to Codeforces.

You'll also need Neovim (>=0.10) and a C++ compiler (`g++`) installed on your machine.

## Installation

To use this config on a new machine (or if you are just trying it out):

```bash
# Backup your existing config just in case
mv ~/.config/nvim ~/.config/nvim.bak

# Clone this repository
git clone git@github.com:RustamSheoran/nvim.git ~/.config/nvim

# Open Neovim to let LazyVim download plugins
nvim
```

### GitHub Copilot Authentication
This setup uses **GitHub Copilot** to provide AI-powered ghost text and code suggestions. On a fresh install, you **must** authenticate Copilot for the suggestions to start working.

After opening Neovim, run the following command in normal mode:
```vim
:Copilot auth
```
Follow the prompts in your browser to sign in. Once authenticated, Copilot will start providing ghost text suggestions automatically as you type.

## The Workflow

*(Note: The `<leader>` key in this setup is mapped to the **Spacebar**)*

### 1. Fetching a Problem
- Open a terminal in your `~/cp/` directory and launch Neovim.
- Open a Codeforces problem in your browser and click the **green plus icon** (Competitive Companion).
- **What happens:** Neovim instantly catches the problem data on port `27121`. It builds the folder structure, creates a `.cpp` file using a custom template, and saves the test cases. 
- **Auto-Jump:** You don't even have to reach for your mouse. Neovim automatically jumps your cursor right inside the `void solve() {` block and drops you into Insert mode so you can start typing immediately.

### 2. Testing Your Code
This setup uses `competitest.nvim` under the hood to manage test cases natively.
- Press `<leader>rr` to run your code against the sample test cases.
- **Custom Inputs:** If you want to test edge cases, you don't have to use the terminal. Press `<leader>ra` to add a new test case, or `<leader>re` to edit existing ones in a clean UI popup. 

### 3. Submitting 
- When your code is ready, press `<leader>rs`.
- Neovim runs a lightning-fast background syntax check (`g++ -fsyntax-only`). If you have a typo or missing semicolon, it aborts the submission and warns you—saving you from a penalty.
- If it compiles cleanly, Neovim sends your code (formatted as C++23) straight to the `cph-submit` browser extension, which submits it to Codeforces automatically.

## Note for Omarchy Users
If you are running Omarchy OS, this Neovim configuration is entirely independent of the OS config files. Omarchy updates will never touch your `~/.config/nvim/` folder, so keeping your config backed up on GitHub guarantees your CP setup is always safe.
