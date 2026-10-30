# Ultra-Fast Competitive Programming IDE (LazyVim + C++17 / C++23)

A high-performance, keyboard-driven Competitive Programming environment built on top of [LazyVim](https://github.com/LazyVim/LazyVim), GCC 16, C++17 / C++23, mold linker, and a native Lua HTTP server.

This setup replaces the need for VS Code and heavy background processes with a completely native, terminal-based workflow that compiles in **~0.27s** (measured on ancient hardware: 2013 4th-gen Intel Core i5-4430; drops to **~70 to 80 ms** on modern CPUs), automatically fetches testcases from your browser, stress-tests solutions against brute forces, runs Google AddressSanitizer pre-submission diagnostics, monitors live verdicts, predicts rating changes, and submits directly to Codeforces with a single keystroke.

<p align="center">
  <a href="#quick-setup"><b>⚡ Quick Setup</b></a> •
  <a href="#arch-setup"><b>🐧 Arch Linux</b></a> •
  <a href="#macos-setup"><b>🍎 macOS</b></a> •
  <a href="#workflow-guide"><b>🚀 Workflow Guide</b></a> •
  <a href="#keymaps"><b>⌨️ Keymap Reference</b></a> •
  <a href="#cp-template"><b>📄 CP Template</b></a>
</p>

---

## Key Highlights

- **⚡ Blazing Fast Compilation (~0.27s on i5-4430 / ~70-80 ms on Modern CPUs):** Uses GCC 16 Precompiled Headers (`bits/stdc++.h.gch`) and the ultra-fast `mold` linker with `-O2` to drop compile times from ~2.7s down to ~0.27s on ancient hardware (Intel Core i5-4430) and down to **~70 to 80 ms** on modern processors.
- **🚀 Native CPH Server in Lua:** Built-in HTTP listener on port `27121` that communicates directly with browser extensions. Zero external dependencies.
- **🛡️ 3-Step Pre-Submission Protection (`<leader>rs`):** Running `<leader>rs` automatically comments out all active `dbg(...)` statements (without deleting them), verifies syntax (`-fsyntax-only`), and compiles with Google AddressSanitizer (`-fsanitize=address,undefined`) against sample testcases. If a memory bug or undefined behavior is detected, submission is halted immediately and your cursor jumps straight to the offending red line!
- **📊 Codeforces Standings & Carrot Elo Rating Predictor (`<leader>rl`):** Native Lua integration displaying live contest standings, solve counts, Carrot rating change predictions (**+24** in green, **-26** in red), next rankup targets (**+239 needed to CM**), celebratory promotion banners (**✨ GUARANTEED CANDIDATE MASTER AFTER THIS CONTEST! CONGRATS! ✨**), Repovive problem difficulty estimations (**~1100\***), and What-If solve projections right inside Neovim.
- **👀 Live Submission Verdict Watcher:** Streams real-time Codeforces submission verdicts through every pretest and system test (**In queue** -> **Running on test 14** -> **Accepted**) with zero manual intervention, safe 1.5s sequential polling, 3.5s adaptive backoff, and native OS desktop alerts.
- **🍪 Zero-Browser Headless Submit (`<leader>rs` / `<leader>rk`):** Non-destructively reads session cookies from Zen Browser or Firefox and submits directly to Codeforces with automatic duplicate code rejection prevention and a global privacy consent toggle.
- **🩺 Pre-Contest Environment Health Check (`<leader>rh`):** Automated 8-point diagnostics on GCC, mold, Bits PCH, 256 MB stack limit, cookies, handle, and Google sanitizers, running silently in the background on opening `~/cp`.
- **🏆 Meta Hacker Cup 1-Click File Runner (`<leader>rm` / `<leader>rf`):** Directory isolation preventing overwritten outputs, 1-click Snacks file picker to choose input from `~/Downloads`, automatic `output.txt` generation, and auto-copying output path to clipboard.
- **🔍 Dedicated Local Debug Runner (`<leader>rd` / `<leader>rx`):** Compiles with `-DLOCAL -DDEBUG` to run all saved testcases, printing variables via `dbg(...)`, wrapping outputs in `------`, and measuring execution time in milliseconds.
- **💥 Automated Stress Testing (`<leader>rb`):** Auto-generates per-problem brute force (`<stem>_brute.cpp`, pre-filled with your template) and generator (`<stem>_gen.cpp`, with random arrays, permutations, strings, and trees). Halts on the first output mismatch and displays the counterexample.
- **🐘 256 MB Stack Limit Protection:** Automatically configures a 256 MB stack limit (`ulimit -s 262144`) matching Codeforces and ICPC standards, eliminating artificial segmentation faults on deep tree DFS ($N = 2 \times 10^5$).
- **🎨 Google C++ Style Guide:** Globally formatted with `clang-format` (`BasedOnStyle: Google`) on save and via `<leader>cf`.
- **📦 On-Demand Algorithm Snippets:** Ultra-clean, minimal default template (~120 lines) paired with instant snippet triggers / fuzzy picker (`rt` or `<leader>rt`) for algorithms and math helpers (`binpow` lambda, `bitops`, `safediv`, `modmath`, `dsu`, `segtree`, `oset`).
- **💡 Distraction-Free & Contest Safe:** GitHub Copilot is disabled by default for anti-cheat contest compliance (toggleable via `<leader>tc`), paired with Treesitter-powered completion filtering, 2-second idle auto-save, hybrid line numbering, and custom statusline metrics.

---

## Prerequisites & Installation

<a id="quick-setup"></a>
### ⚡ One-Click Automated Setup (`setup.sh`)

If you want an automated, zero-effort installation, clone the repository and run `setup.sh`:

```bash
# 1. Clone this repository
git clone git@github.com:RustamSheoran/nvim.git ~/.config/nvim
cd ~/.config/nvim

# 2. Run the automated setup script
bash setup.sh
```

**What `setup.sh` does automatically:**
- **Config Backup:** Moves any existing `~/.config/nvim` to `~/.config/nvim.bak`.
- **System Detection:** Detects Arch Linux (`pacman`, `/proc`) or macOS (`brew`).
- **Non-Interactive Package Installation:** Automatically installs compilers and tools (`pacman -S --noconfirm --needed neovim gcc clang mold nodejs` on Arch Linux, or `brew install neovim gcc llvm mold node` on macOS). Only prompts once for `sudo` password if needed.
- **Stack Limit Expansion:** Permanently writes 256 MB stack limits (`ulimit -s 262144` on Arch Linux, `ulimit -s 65520` on macOS) into `~/.bashrc` and `~/.zshrc`.
- **GCC Precompiled Headers:** Automatically locates `bits/stdc++.h` and compiles `bits/stdc++.h.gch` for instant compilation (~0.27s on ancient i5-4430 / ~70-80 ms on modern hardware).

---

### Manual Requirements
- **Neovim** (>= 0.10)
- **C++ Compiler:** GCC (`g++`) or Clang (`clang++`) with C++17 / C++20 / C++23 support
- **Google Sanitizers:** Google AddressSanitizer (`libasan`) and UndefinedBehaviorSanitizer (`libubsan`)
- **mold Linker:** High-speed modern linker (`-fuse-ld=mold`)
- **Browser Extensions:**
  1. [Competitive Companion](https://github.com/jmerle/competitive-companion) -> Parses problem statements and sample test cases from Codeforces, AtCoder, etc.
  2. [cph-submit](https://github.com/agrawal-d/cph-submit) -> Automates submitting solution code to Codeforces directly from the editor.

---

<a id="arch-setup"></a>
### Setup Guide for Arch Linux

Arch Linux provides the latest GCC, Clang, Google sanitizers, and `mold` directly in the official repositories.

```bash
# 1. Install Neovim, compilers, Google sanitizers, and mold linker
sudo pacman -S neovim gcc clang mold

# 2. Increase stack limit to 256 MB in your shell configuration
echo "ulimit -s 262144" >> ~/.bashrc
echo "ulimit -s 262144" >> ~/.zshrc

# 3. Apply the stack limit to your current terminal session
ulimit -s 262144
```

> [!NOTE]
> On Arch Linux, `gcc` and `clang` packages include Google AddressSanitizer (`libasan.so`) and UndefinedBehaviorSanitizer (`libubsan.so`) out of the box. No separate sanitizer packages are required.

---

<a id="macos-setup"></a>
### Setup Guide for macOS

On macOS, install Neovim, toolchains, and `mold` using Homebrew.

```bash
# 1. Install Neovim, GCC / LLVM Clang, mold, and clang-format via Homebrew
brew install neovim gcc llvm mold node clang-format

# 2. Increase shell stack limit in ~/.zshrc
echo "ulimit -s 65520" >> ~/.zshrc

# 3. Apply the stack limit to your current terminal session
ulimit -s 65520
```

> [!IMPORTANT]
> **macOS Stack Limits & Binary Flags:**
> The macOS Darwin kernel enforces a maximum shell soft limit of `65520` KB (~64 MB) for `ulimit -s`.
> For complete 256 MB stack parity with online judges, you can pass `-Wl,-stack_size,0x10000000` (256 MB) during linking. Clang and Apple Clang have Google AddressSanitizer and UndefinedBehaviorSanitizer built directly into the runtime (`-fsanitize=address,undefined`).

<details>
<summary><b>Adding &lt;bits/stdc++.h&gt; on macOS (Click to Expand)</b></summary>

Unlike Linux GCC, macOS ships with Apple Clang (LLVM libc++), which does not bundle the GNU GCC-specific `<bits/stdc++.h>` header by default.

Here is how to set up `<bits/stdc++.h>` on macOS:

#### Method 1: Install `bits/stdc++.h` for Clang (Recommended)

1. Create the `bits` directory in your include search path:
   - **Apple Silicon (M1/M2/M3/M4):**
     ```bash
     mkdir -p /opt/homebrew/include/bits
     ```
   - **Intel Mac:**
     ```bash
     sudo mkdir -p /usr/local/include/bits
     ```

2. Download the standard library header into that directory:
   - **Apple Silicon:**
     ```bash
     curl -sSL "https://raw.githubusercontent.com/gcc-mirror/gcc/master/libstdc%2B%2B-v3/include/precompiled/stdc%2B%2B.h" -o /opt/homebrew/include/bits/stdc++.h
     ```
   - **Intel Mac:**
     ```bash
     sudo curl -sSL "https://raw.githubusercontent.com/gcc-mirror/gcc/master/libstdc%2B%2B-v3/include/precompiled/stdc%2B%2B.h" -o /usr/local/include/bits/stdc++.h
     ```

Clang automatically searches `/opt/homebrew/include` and `/usr/local/include`, allowing `#include <bits/stdc++.h>` to compile cleanly across all your projects.

#### Method 2: Use Homebrew GCC

If you prefer using native GNU GCC on macOS:

```bash
# 1. Install GCC via Homebrew
brew install gcc

# 2. Add alias to ~/.zshrc (replace 14 with your installed GCC version)
echo 'alias g++="g++-14"' >> ~/.zshrc
source ~/.zshrc
```

Homebrew GCC includes `<bits/stdc++.h>` out of the box.

</details>

---

### Installation

```bash
# 1. Backup your existing configuration (if any)
mv ~/.config/nvim ~/.config/nvim.bak

# 2. Clone this repository
git clone git@github.com:RustamSheoran/nvim.git ~/.config/nvim

# 3. Launch Neovim (LazyVim will automatically install all plugins)
nvim
```

### GitHub Copilot Setup & Contest Mode
This config includes GitHub Copilot for inline ghost text suggestions across all programming languages (C++, Python, TypeScript, Java, HTML, Go, Rust, etc.).
- **Contest Mode (Off by Default):** Copilot starts **disabled by default** to protect you from accidental anti-cheat violations during rated contests. Press **`<leader>tc`** to toggle Copilot on or off anytime.
- **Log In:** Press **`<leader>tl`** -> your device code is auto-copied to clipboard, paste it at [github.com/login/device](https://github.com/login/device)
- **Log Out:** Press **`<leader>to`** -> signs out of Copilot anytime

---

## Performance Architecture

### Precompiled Header (`bits/stdc++.h.gch`)
In competitive programming, `#include <bits/stdc++.h>` pulls in over 300,000 lines of standard library templates, which normally takes ~2.7s to compile from scratch every single run.

Precompile the header directly into GCC's internal include directory for your chosen language standard:

```bash
# Precompile for C++17 (Recommended -> ~0.32s instant compiles):
sudo g++ -O2 -std=c++17 -x c++-header /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h -o /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h.gch/c++17_O2.gch
sudo g++ -std=c++17 -x c++-header /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h -o /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h.gch/c++17.gch

# Or precompile for C++20 / C++23 if using those standards:
sudo g++ -O2 -std=c++20 -x c++-header /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h -o /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h.gch/c++20_O2.gch
sudo g++ -O2 -std=c++23 -x c++-header /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h -o /usr/include/c++/16/x86_64-pc-linux-gnu/bits/stdc++.h.gch/c++23_O2.gch
```

- **GCC PCH Rule:** GCC requires the precompiled header to be the *first* token encountered. Compiling with `-std=c++17 -O2` allows GCC to instantly memory-map the precompiled header, reducing compilation time down to **~0.32s**.
- **No `-include cassert`:** Flags like `-include cassert` bypass the PCH and recompile from scratch. Our compile pipeline is clean and preserves the PCH cache.

> [!TIP]
> **Hardware Context & Even Faster Modern Performance:**
> These benchmark figures (~0.32s with C++17 PCH + mold, down from ~2.7s raw GCC) were measured on a 2013 4th-generation Intel Core i5-4430 CPU (Haswell, 4 cores / 4 threads) with DDR3 memory.
> On modern processors (such as AMD Ryzen 7000/9000 or Intel 13th/14th Gen with high IPC, 32MB+ L3 cache, and DDR5 RAM), compile times drop down to **~60 to 80 milliseconds**, making solution test runs feel completely instantaneous.

> [!IMPORTANT]
> **Arch Linux GCC Updates (`pacman -Syu`):**
> On Arch Linux, when `pacman -Syu` eventually upgrades GCC to a newer version in the future, the `/usr/include/c++/16/` path will shift to the new version number.
> If compilation ever jumps back to ~2.7s after a big system upgrade, simply re-run the two `sudo g++ ...` commands above (or re-run `bash setup.sh`, which automatically detects your new GCC path) to restore instant ~0.32s compilation.

### 256 MB Stack Size Protection (`ulimit -s 262144`)
By default, Linux limits process call stacks to 8 MB (`ulimit -s 8192`), causing artificial `Segmentation fault` crashes on deep recursion (e.g. $N = 2 \times 10^5$ Tree DFS), even when code is 100% correct.

All Neovim CP test runners (`debug_runner`, `stress`, and `competitest`) automatically set `ulimit -s 262144` (256 MB):
- **Matches Codeforces & ICPC:** Exactly matches the standard 256 MB stack limit of online judges.
- **Essential for Meta Hacker Cup:** In Meta Hacker Cup, problems are run locally on your own machine. Deep recursions will crash without this limit.
- **Zero Idle Memory Consumption:** In Linux, stack limits are a ceiling, not pre-allocated RAM. A solution using 50 KB uses only 50 KB.
- **Infinite Recursion Safety:** Accidental runaway recursion hits 256 MB and exits immediately in 0.01s with SIGSEGV, never freezing your PC.

### Ultra-Fast `mold` Linker
Traditional linkers (`ld` or `gold`) take between 200ms to 500ms just to link standard C++ templates.
The `mold` linker is a modern, highly-parallel linker designed specifically for instantaneous developer turnaround.
- Injected via `-fuse-ld=mold`.
- Links competitive programming binaries in **under 10 milliseconds**.
- Combined with GCC PCH, overall compile and link cycle finishes in **~0.27s** on ancient i5-4430 hardware and drops down to **~70 to 80 ms** on modern processors.

### Google AddressSanitizer & UndefinedBehaviorSanitizer
Memory safety bugs (such as 1-based indexing into a 0-indexed vector, buffer overflows, or signed integer overflow) often go unnoticed locally on sample tests because uninitialized memory might happen to be zero, only to produce **Runtime Error** or **Wrong Answer** on Codeforces test 14.
- Pre-submission checks run with `-fsanitize=address,undefined -g`.
- Catches out-of-bounds array access, null pointer dereference, signed overflow, and memory corruption instantly.
- Neovim parses sanitizer diagnostics and jumps your cursor directly to the offending line with a red highlight before your submission touches the judge.

### Clangd LSP Optimization
To eliminate typing lag and noisy diagnostics:
- `--clang-tidy=false`: Disables static analysis warnings (e.g. yellow warnings on `bit_width` or magic numbers) while keeping real syntax errors fully active.
- `--header-insertion=never`: Prevents unwanted automatic `#include` additions.
- `inlay_hints = { enabled = false }`: Disables virtual inline parameter hints that cause stutter during rapid typing.
- **CP Header Warning Suppression:** When Neovim is open in `~/cp`, unused include warnings (e.g. `Included header ... is not used directly`) are cleanly filtered out via Clangd LSP handlers and `~/cp/.clangd`, keeping your diagnostics list 100% focused on genuine logic and syntax errors.

---

<a id="workflow-guide"></a>
## The Workflow Guide

*(Note: The `<leader>` key is mapped to **Spacebar**)*

### 1. Pre-Contest Environment Health Check (`<leader>rh` & Auto on Startup)
Press `<leader>rh` before any rated round (or open any file inside `~/cp` for an automatic background check) to verify your environment via [`lua/config/cp_health.lua`](lua/config/cp_health.lua):
1. **GCC Compiler:** Verifies `g++` path and version.
2. **Mold Fast Linker:** Confirms `mold` is active for fast linking.
3. **Bits Precompiled Header:** Verifies `<bits/stdc++.h.gch>` exists and loads in ~0.12s.
4. **Stack Limit:** Confirms your shell has 262,144 KB or unlimited stack for recursion safety.
5. **CF Cookie Submission:** Checks if Zen/browser cookies are available for headless submit.
6. **Codeforces Handle:** Confirms handle is set for standings and live watcher.
7. **Companion Server:** Verifies port 27121 is ready for Competitive Companion.
8. **Sanitizer Protection:** Validates that `-fsanitize=address,undefined` executes cleanly.

> [!TIP]
> Opening Neovim in your `~/cp` directory automatically verifies your environment in the background via [`lua/config/autocmds.lua`](lua/config/autocmds.lua). If all 8 checks pass, a subtle notification confirms readiness; if anything needs attention, the full checklist pops up immediately.

### 2. One-Click Problem Fetching
1. Open Neovim in your `~/cp` directory.
2. In your browser, open any Codeforces or AtCoder problem and click the **green plus icon** (Competitive Companion).
3. **What happens automatically:**
   - The native Lua HTTP server on port `27121` receives the problem statement.
   - It creates the folder hierarchy: `~/cp/<Judge>/<Contest>/<Problem>.cpp`.
   - Saves sample inputs and outputs in `<Problem>.testcases` and the problem URL in `<Problem>.url`.
   - Injects the default CP template (`cp_template.cpp`).
   - **Auto-Jump Magic:** Neovim automatically locates `void solve() {`, places your cursor inside with 4-space indentation, and switches into **Insert Mode** so you can start coding your logic immediately.

#### Problem Directory Anatomy
When a problem is fetched, Neovim creates an organized problem workspace:

```text
~/cp/Codeforces/Round_1010/
├── A.cpp              # Your solution code
├── A.testcases        # Saved sample and custom testcases (inputs and outputs)
├── A.url              # Problem URL for browser jump (<CR> / <leader>ru) and submit (<leader>rs)
├── A_brute.cpp        # Auto-generated brute force solution (<leader>rb / <leader>rB)
└── A_gen.cpp          # Auto-generated random testcase generator (<leader>rb / <leader>rG)
```

- **Persistent Testcases:** Custom testcases added with `<leader>ra`, edited with `<leader>re`, or deleted with `<leader>rD` are saved directly into `<Problem>.testcases`. They persist permanently across Neovim sessions.

### 3. On-Demand Algorithm Snippets & Interactive Picker
Instead of bloating your base template with thousands of lines of unused algorithms, insert algorithms on demand:
- **Interactive Picker (`<leader>rt` or `rt`):** Press `<leader>rt` (or `rt`) in normal mode to open a fuzzy picker showing every algorithm, its prefix, and a live syntax-highlighted code preview. Press `<Enter>` on any algorithm to insert it instantly at your cursor!
- **Insert Mode Completion:** Type any prefix below while coding and press `<Enter>` or `<Tab>` to expand it directly.
- **Find Files Across PC (`<Space><Space>`):** Press Space twice to open the fuzzy file finder across your entire home directory.
- **CP Template Shortforms:** Every snippet uses the shortforms from your CP template (`vvi`, `vpll`, `vvll`, `pb`, `eb`, `each`, `rep`, `rep1`, `rrep`, `min_pq`, `sz`, `all`, `INFLL`, `chmin`, `chmax`) for ultra-compact, clean code.

<details>
<summary><b>View All Available Algorithm Snippets & Shorthands (50+ Templates)</b></summary>

| Prefix | Algorithm / Data Structure | Details |
|---|---|---|
| `cp` | **Default CP Template** | Clean, modern base template (~110 lines) |
| `adj` / `graph` | **Read Graph (Adjacency List)**| Declares `vvi adj(n + 1)` and reads $m$ edges |
| `tree` / `readtree` | **Read Tree** | Declares `vvi adj(n + 1)` and reads $n - 1$ tree edges |
| `wadj` / `wgraph` | **Read Weighted Graph** | Declares `vector<vpll> adj(n + 1)` and reads $m$ weighted edges |
| `dfs` / `gdfs` | **Graph DFS** | Self-contained graph DFS with `adj`, `vis` tracking, and `add_edge` |
| `treedfs` / `tdfs` | **Tree DFS** | Self-contained tree DFS with `adj`, `add_edge`, and `(u, p)` parent skip |
| `bfs` | **Breadth-First Search** | Self-contained unweighted BFS with `adj`, `add_edge`, and `dist` array |
| `01bfs` | **0-1 BFS** | Self-contained 0-1 BFS with weighted `adj`, `add_edge`, and `deque` |
| `gridbfs` / `bfs2d` | **Grid BFS (2D)** | 2D matrix BFS using template `dx`/`dy` and `rep(d, 4)` |
| `dijkstra` / `dijk` | **Dijkstra Algorithm** | Self-contained Dijkstra with weighted `adj`, `add_edge`, and `pq` |
| `topo` / `toposort` | **Topological Sort** | Self-contained Kahn's algorithm with `adj`, `in_degree`, and `add_edge` |
| `bellman` | **Bellman-Ford** | Negative weight edges & negative cycle detection |
| `floyd` | **Floyd-Warshall** | All-pairs shortest paths in $\mathcal{O}(V^3)$ |
| `kruskal` / `mst` | **Kruskal's MST** | Minimum Spanning Tree using DSU |
| `lca` / `binary_lifting` | **LCA & Binary Lifting** | Tree LCA, distance, and $k$-th ancestor in $\mathcal{O}(\log N)$ |
| `scc` / `tarjan` | **Tarjan's SCC** | Strongly Connected Components condensation in $\mathcal{O}(V + E)$ |
| `segtree` | **Iterative Segment Tree** | Cache-friendly point update & range query |
| `lazysegtree` / `lazyst` | **Lazy Segment Tree** | Range add & range sum queries in $\mathcal{O}(\log N)$ |
| `sparsetable` / `rmq` | **Sparse Table** | Static Range Minimum Query in $\mathcal{O}(1)$ |
| `fenwik` / `bit` | **Binary Indexed Tree** | 0-indexed BIT with binary lifting `lower_bound` |
| `dsu` / `unionfind`| **Disjoint Set Union** | Path compression + component sizes |
| `dinic` / `maxflow` | **Dinic's Algorithm** | Fast Maximum Network Flow in $\mathcal{O}(V^2 E)$ |
| `trie` | **Trie (Prefix Tree)** | Alphabetical prefix search & word counting |
| `bintrie` / `xortrie` | **Binary Trie** | Maximum / minimum XOR queries |
| `extgcd` / `modinv` | **Extended GCD & Inverse** | Bézout coefficients and modular inverse |
| `seive` / `prime` | **Linear Sieve & Primes** | $\mathcal{O}(N)$ sieve with SPF & prime factorization |
| `phi` / `totient` | **Euler's Totient** | $\phi(N)$ count of coprimes in $\mathcal{O}(\sqrt{N})$ |
| `primefact` / `factors` | **Prime Factorization** | $\mathcal{O}(\sqrt{N})$ prime factor decomposition |
| `binpow` / `power` / `bpow` | **Binary Exponentiation (Lambda)** | Modular power lambda with `__int128` overflow protection |
| `bitops` / `popcount` / `bits` | **Bit Operations** | Fast builtins suite (`topbit`, `botbit`, `popcount`, `bit_width`) |
| `safediv` / `cdiv` / `fdiv` | **Safe Division** | Floor & ceiling division safe against negative integers |
| `modmath` / `mod` / `modular` | **Modular Math Suite** | `binpow`, `mod_add`, `mod_sub`, `mod_mul`, `mod_inv`, `mod_div` |
| `modlambdas` / `modl` | **Modular Math Lambdas** | Full modular math suite as `solve()`-local lambdas |
| `pref` / `psum` | **1D Prefix Sum** | Static 1D range sum query lambda in $\mathcal{O}(1)$ with `vll` and `rep` |
| `diff` / `diff1d` | **1D Difference Array** | Range addition updates with `vll` and `rep` |
| `pref2d` | **2D Prefix Sums** | Static 2D grid range sum query in $\mathcal{O}(1)$ with `vvll` and `rep` |
| `diffarray` / `diff2d` | **2D Difference Array** | 2D rectangular range increment updates with `vvll` and `rep1` |
| `rollback_dsu` / `dsu_rollback` | **Rollback DSU** | DSU with history snapshots and rollback undo |
| `weighted_dsu` / `pot_dsu` | **Weighted DSU** | Potential DSU tracking element differences |
| `fenwick2d` / `bit2d` | **2D Fenwick Tree** | 2D BIT point updates and rectangular range sums |
| `lichao` / `cht` | **Li-Chao Tree** | Dynamic Convex Hull Trick segment tree for line queries |
| `prim` / `prim_mst` | **Prim's MST** | Priority-queue based Minimum Spanning Tree |
| `kmp` / `prefix_function` | **KMP Algorithm** | $\pi$ prefix function and substring pattern matching in $\mathcal{O}(N)$ |
| `zfunc` / `z_function` | **Z-Algorithm** | Linear time string matching $Z$-array in $\mathcal{O}(N)$ |
| `manacher` / `palindromes` | **Manacher's Algorithm** | Palindromic substring radii in $\mathcal{O}(N)$ |
| `strhash` / `shash` / `polyhash` | **String Hashing (Double)** | Anti-hack double rolling hash with `MOD1` & `MOD9` in $\mathcal{O}(1)$ |
| `isprime` / `miller_rabin` | **Miller-Rabin Primality** | Deterministic 64-bit integer primality test in $\mathcal{O}(k \log N)$ |
| `cycle` / `detect_cycle` | **Cycle Detection** | 3-color DFS directed cycle detection in $\mathcal{O}(V + E)$ |
| `fastmap` / `hashmap`| **Anti-Hack Hash Table** | 5.5x faster PBDS `gp_hash_table` with `splitmix64` |
| `oset` / `ordered_set`| **Policy-Based Ordered Set** | PBDS `order_of_key` and `find_by_order` in $\mathcal{O}(\log N)$ |
| `cpp` | **Full Library Template** | Complete 950-line monolithic library |
| `lcc` | **LeetCode Template** | Minified 1-line helper template |

#### Fast Macro & Shorthand Expansion Snippets:
- `pb` $\rightarrow$ `pb(...)` (prioritized over `pop_back`)
- `eb` $\rightarrow$ `eb(...)` (prioritized over `emplace_back`)
- `fi` / `se` $\rightarrow$ `fi` / `se` (`first` / `second`)
- `mp` $\rightarrow$ `mp(a, b)` (`make_pair`)
- `rep` $\rightarrow$ `rep(i, n) { ... }` with `<Tab>` navigation between `i` and `n`.
- `rep1` $\rightarrow$ `rep1(i, n) { ... }` (1-indexed loop).
- `rrep` $\rightarrow$ `rrep(i, n) { ... }` (reverse loop).
- `forr` / `roff` $\rightarrow$ forward / reverse range loops.
- `each` $\rightarrow$ `each(x, a) { ... }` (range-for loop).
- `all` / `rall` $\rightarrow$ `all(x)` / `rall(x)`.
- `sz` $\rightarrow$ `sz(x)` (prioritized over `size`).
- `vi` / `vll` / `vvi` / `vvll` $\rightarrow$ vector type shorthands.
- `min_pq` $\rightarrow$ `min_pq<ll>`.
- `chmin` / `chmax` $\rightarrow$ updates variable if smaller/larger.
- `dbg` $\rightarrow$ `dbg(x);`
</details>

### 4. Google C++ Code Formatting
Formatted with `clang-format` enforcing the official **Google C++ Style Guide** (`~/.clang-format`):
- **2 Spaces Indentation:** Clean, compact nested logic.
- **Attached Braces:** Opening braces stay on the same line (`if (n > 0) {`).
- **Left-Aligned Pointers:** `int* ptr;`, `vector<int>& v;`.
- **On by Default:** Automatically formats your code on save or whenever you leave insert mode. Press `<leader>cf` to manually format anytime.

### 5. Running Sample Testcases (`<leader>rr`)
- Press `<leader>rr` to run your solution against the sample testcases using `competitest.nvim`.
- Compiles in **~0.32s** with `g++ -O2 -std=c++17 -fuse-ld=mold`.
- **Clean Diff View:** Displays inputs, outputs, and expected outputs side by side with green/red status.
- **Custom Cases:** Press `<leader>ra` to add custom test cases, `<leader>re` to edit, or `<leader>rD` to delete.
- **Fast Close:** When the CompetiTest window is open, press single key **`q`**, **`Q`**, or **`<Esc>`** to close it instantly.

### 6. Local Debugging (`<leader>rd` or `<leader>rx`)
When you want to inspect variables, verify execution time, or test custom inputs:
- Press `<leader>rd` (or `<leader>rx`).
- Compiles with **`-DLOCAL -DDEBUG`**.
- **What it does:**
  1. Runs each saved sample testcase of the problem:
     - Prints the Input and Expected Output.
     - Prints your output with `------` testcase separators.
     - Prints variable values logged with `dbg(...)` (e.g. `dbg(n, arr)` $\rightarrow$ `[n, arr]: 5 | 1 2 3 4 5`).
     - Prints execution time measured by Chrono Clock (`[Time: X.XX ms]`).
  2. Offers an optional interactive prompt to test arbitrary manual inputs.
- **Zero Online Judge Cost:** On Codeforces (where `-DDEBUG` and `-DLOCAL` are not defined), `dbg(...)` automatically compiles into `42` (a zero-cost no-op stripped by the compiler). You never need to delete your debug statements before submitting!

### 7. Automated Stress Testing (`<leader>rb`)
When you are stuck on *"Wrong Answer on test 4"* and sample cases pass:
- Press `<leader>rb` (Run Brute-force / Stress test).
- **Per-Problem Isolated Files:**
  - Every problem has its own isolated brute force and generator (e.g. `A_brute.cpp` & `A_gen.cpp` for `A.cpp`, `B_brute.cpp` & `B_gen.cpp` for `B.cpp`), so you never overwrite files across an entire contest!
  - `<stem>_brute.cpp`: Created with your clean CP template ready for your slow $\mathcal{O}(N^2)$ brute-force logic.
  - `<stem>_gen.cpp`: Pre-loaded with generator helpers (`rand_int`, `rand_array`, `rand_permutation`, `rand_string`, `rand_tree`).
- **Split Navigation:**
  - Press `<leader>rB` to open the problem's brute force (`<stem>_brute.cpp`) in a vertical split beside your solution.
  - Press `<leader>rG` to open the problem's generator (`<stem>_gen.cpp`) in a vertical split beside your solution.
  - Seamless navigation: you can press `<leader>rb` from your solution, brute force, or generator, and it will automatically stress-test the correct problem.
  - Close split windows with `:q`, `:Q`, or `Ctrl+w, c`.
- **Automated Loop:** Neovim compiles all three programs and loops random testcases until the first output mismatch is detected.
- **Counterexample Display:** Immediately halts and prints:
  - Failing testcase number
  - Full input (`__in.txt`)
  - Your solution output (`__out_sol.txt`)
  - Brute force output (`__out_brute.txt`)
- **100% Submission Safety:** Stress testing files are completely isolated. Submitting (`<leader>rs`) sends **only** your solution buffer.

### 8. Diagnostics with Google AddressSanitizer (`<leader>rz`)
- Press `<leader>rz` to compile your code with `-fsanitize=address,undefined -g`.
- Automatically catches:
  - Segmentation faults / null pointer dereferences.
  - Array out-of-bounds access (`arr[n]` when size is $n$).
  - Signed integer overflow and undefined behavior.
- Prints the **exact line number** of the memory bug in your source code!

### 9. Three-Step Pre-Submission Protection & Red-Line Jump (`<leader>rs`)
When your solution is ready to submit:
1. Press `<leader>rs`.
2. **Step 1: Auto-Comment Debugs:** Automatically finds and comments out all active `dbg(...)` statements (e.g. `// dbg(x);`) in your buffer without deleting them, then saves your file.
3. **Step 2: Syntax Check:** Runs `g++ -std=c++17 -fsyntax-only`. If there is a typo or missing semicolon, submission aborts immediately.
4. **Step 3: Sanitizer Sanity Check & Red-Line Jump:** Compiles with `-fsanitize=address,undefined -g` and runs your binary against all saved sample testcases.
   - If ANY testcase fails (crash, assertion failure, segmentation fault, out-of-bounds memory access, or sanitizer runtime error), **submission is aborted immediately and your code is NEVER submitted to Codeforces or the online judge**.
   - Neovim displays a clear error alert and jumps your cursor directly to the offending line in your source code with a red highlight, protecting you from an accidental 50-point penalty on Codeforces!
5. If and only if all pre-submission checks pass cleanly, Neovim transmits the code to the `cph-submit` browser extension, submitting it to Codeforces automatically.

> [!IMPORTANT]
> **Fail-Safe Submission Lock:**
> If any testcase fails to execute cleanly or triggers an AddressSanitizer/UBSan violation on sample cases, submission is permanently blocked. Your code will never be sent to the judge until all sample tests execute without errors.

> [!TIP]
> You can also manually comment or uncomment all `dbg` calls anytime:
> - `<leader>rc`: Comment all active `dbg(...)` statements in the file.
> - `<leader>rC`: Uncomment all `dbg(...)` statements in the file.

#### Headless 1-Click Codeforces Submission & Privacy Consent (`<leader>rk`)
Neovim includes a headless direct submission pipeline for Codeforces via [`lua/config/cf_cookie_submit.lua`](lua/config/cf_cookie_submit.lua):
- **Instant Headless Submission:** Reads session cookies non-destructively from Zen Browser (or Firefox, Floorp, LibreWolf, Waterfox) using SQLite read-only immutable mode. Submits directly via curl with zero browser popup, automatically adds a unique timestamp token to prevent duplicate submission rejection, and streams testcase evaluation automatically in real time.
- **Automatic Fallback:** If not signed in, Neovim opens `https://codeforces.com/enter` in your browser. If a Cloudflare challenge occurs, Neovim automatically falls back to browser-based submission via `cph-submit`.
- **Global Privacy Toggle (`<leader>rk`):** If you prefer not to use headless cookie extraction, press `<leader>rk` to disable it globally. When disabled, Neovim will **never** read, touch, or inspect your browser cookies, and will strictly use the browser extension fallback for every submission. Your preference persists permanently across Neovim sessions.

#### Codeforces Submission Language IDs (`cph_server.lua`)
When submitting with `<leader>rs`, Neovim sends the language ID to `cph-submit`. You can customize `languageId` in `lua/config/cph_server.lua`:

| Compiler Option on Codeforces | Language ID | Notes |
| :--- | :--- | :--- |
| **GNU G++23 14.2 (64 bit, msys2)** | **`"91"`** | **Default / Recommended:** Native 64-bit speed, 64-bit registers, and full `__int128_t` (`i128`) support. Backward-compatible with all C++17 code. |
| **GNU G++20 13.2 (64 bit, winlibs)** | **`"89"`** | Full 64-bit speed with C++20 on Codeforces. |
| **GNU G++17 7.3.0** | **`"54"`** | 32-bit compiler. Note: `__int128_t` is not supported on 32-bit GCC. |

#### Multi-Judge Support & Automated Browser Submission
While Codeforces submissions are handled natively via the `cph-submit` extension, `<leader>rs` also fully supports:
- **AtCoder, CSES, CodeChef, LeetCode, Kattis, SPOJ, and AlgoZenith**

**How it works for non-Codeforces platforms:**
1. Runs the same 3-step verification (comments debug statements, verifies syntax, and runs Google ASan/UBSan check against sample testcases).
2. Automatically copies the sanitized, clean code to your system clipboard (`+` and `"` registers).
3. Automatically opens the problem submission page in your default browser, ready for immediate paste and submit!

### 10. Automated Live Submission Verdict Watcher
Whenever you submit a problem using `<leader>rs` (or headless cookie submit), Neovim automatically streams the real-time evaluation verdict with zero manual intervention required:
- Sequential 1.5-second polling interval with custom browser User-Agent headers, preventing Cloudflare 403 blocks and API rate limits while eliminating contest anxiety.
- Displays live evaluation states inside Neovim notifications:
  - **In queue**
  - **Running on test 1**
  - **Running on test 14...**
- Concludes immediately upon final verdict:
  - **Accepted** (styled in green)
  - **Wrong answer on test 7** (styled in red)
  - **Time limit exceeded on test 12**
  - **Memory limit exceeded on test 3**
  - **Compilation error**
- **Native OS Desktop Notification:** When judging completes, Neovim triggers a native desktop notification (`notify-send` on Linux, `osascript` on macOS) for the final verdict (**Accepted** / **Wrong Answer**). Intermediate testcase notifications stay inside Neovim so your desktop is never spammed.

#### Codeforces API Rate Limiting Architecture & Safety Guarantees
Online judges enforce strict API consumption rules to protect their backend servers during high-volume rated contests. Here is how Codeforces rate limiting functions and how our native watcher guarantees you will never be throttled or banned:

1. **The Token Bucket Algorithm:**
   - Codeforces enforces a Token Bucket rate limiting algorithm with a capacity of **5 tokens** (requests).
   - The token bucket continuously refills at a steady rate of **1 token per second**.
   - **Burst Handling:** You can safely fire a burst of 2 to 3 requests in a single second because the token bucket absorbs the spike without issue.
   - **Sustained Consumption:** If a script sends requests continuously faster than 1 request per second (e.g. polling every 500 ms or 800 ms), the bucket runs out of tokens within 8 to 10 seconds.

2. **The Two Rate Limiting Tiers:**
   - **Tier 1 (Soft API Throttle):** When the token bucket runs dry, the Codeforces API returns a JSON response with `"status": "FAILED"` and `"comment": "Call limit exceeded"`. This is a temporary soft throttle. If your client pauses requests for **1 to 2 seconds**, the token bucket replenishes with 1 to 2 new tokens and requests succeed again immediately.
   - **Tier 2 (Cloudflare WAF IP Ban):** If an aggressive script ignores the `Call limit exceeded` error and keeps spamming requests without backing off, Cloudflare's Web Application Firewall (WAF) classifies the traffic as a denial-of-service attack. Cloudflare then issues a full HTTP 403 Forbidden captcha block. This Tier 2 ban locks your IP address out of the Codeforces API for **10 to 30 minutes**.

3. **Why Our Watcher Guarantees Zero Rate Limits or Bans:**
   - **Fast 700ms Polling with 1000ms Wire Floor:** Initial status check fires in just 400ms for near-instant first testcase feedback. Subsequent polls wait 700ms after response, with a hard floor of >= 1000ms on the wire to prevent API rate limits.
   - **Response Latency & Judging Time Feedback:** Every testcase poll and final verdict displays the exact response time and total time taken, e.g. `⏳ [A] Running on test 1... [took 0.3s to get response]` and `🎉 ACCEPTED! (took 4.6s, response in 0.3s)`.
   - **3.5s Adaptive Backoff:** If a `Call limit exceeded` response is ever received (for example, if another browser tab, extension, or tool is concurrently accessing the API), the watcher detects it immediately and backs off for **3.5 seconds**. This gives the bucket enough time to regenerate 3 to 4 tokens, fully clearing the Tier 1 throttle before any new request is dispatched and completely preventing Tier 2 Cloudflare WAF bans.
   - **Browser User-Agent Header:** Every query sends a realistic browser User-Agent header, preventing Cloudflare from flagging your requests as unauthenticated bot scrapers.
   - **Zero Contest Anxiety:** You never need to manually refresh standings or submit pages during a round. The watcher operates quietly in the background and delivers an instant OS notification the second your final verdict arrives.

### 11. Codeforces Standings & Carrot Elo Rating Predictor (`<leader>rl`)
Press `<leader>rl` while working on any contest problem to open the live Codeforces Contest HUD.

- **Contest Auto-Detection:** Automatically extracts the contest ID from the problem `.url` companion file. If invoked in an independent buffer, prompts for the contest ID.
- **Configurable Handle:** Remembers your Codeforces handle in `codeforces_handle.txt`. Prompts on first use. Press `s` inside the HUD to change your handle at any time.
- **Contest Date & Relative Age:** Displays when the contest took place along with its calendar age from today (e.g. `📅 Date: 2024-06-11 (2y 4m 19d old contest)` or `(today)`).
- **Persistent Disk Caching:** Once contest standings and ratings are fetched for a completed round, they are stored on disk in `~/.cache/nvim/codeforces/contest_<id>.json`. Future opens of finished or past contests load near-instantly in 2 to 5 ms (`[Cached | 'r' to reload]`). Press `r` inside the HUD anytime to force a fresh re-fetch from the Codeforces API.
- **Contest Overview & Status:**
  - Displays contest title and active phase (`CODING`, `PENDING_SYSTEM_TEST`, `SYSTEM_TEST`, `FINISHED`).
  - Displays your official rank in bold (**Rank #1591**), followed by raw standings rank in faded gray (**(#1290)**) when they differ.
  - Displays solved problem count and total accumulated points (**Points: 2244 | Solved: 3/7**).
- **Carrot Elo Rating Predictor:**
  - Implements the complete Carrot Elo rating prediction algorithm natively in Lua.
  - Displays your predicted rating delta: positive changes in bold green (**+24**), negative changes in bold red (**-26**).
  - Next Tier Target: displays remaining points needed to reach your next rankup tier (e.g. **(+239 needed to CM)** styled in purple).
  - Guaranteed Promotion Alert: when your predicted rating change guarantees crossing into the next tier (e.g. Expert -> Candidate Master), displays a celebratory banner: **✨ GUARANTEED CANDIDATE MASTER AFTER THIS CONTEST! CONGRATS! ✨**
- **Repovive Problem Difficulty Estimation:**
  - Ported natively from Repovive: performs a binary search over competitor ratings and solver count to calculate live estimated problem difficulty (e.g. **[A] ~1100\***, **[B] ~1300\***, **[C] ~1500\***).
  - System Test Safety: during the **SYSTEM_TEST** phase (when submissions are being re-run and solver counts fluctuate), the binary search is automatically bypassed and displays **-** to prevent distorted ratings.
- **Unofficial Solves Handling:**
  - Standard standings query retrieves official participants.
  - Unofficial submission fetching (`user.status`) is only executed when you are out of the contest or solving unofficially.
- **What-If Solve Predictions:**
  - Evaluates remaining unsolved problems and computes your projected rank and rating gain if you solve that problem next:
    **• Solve [D] [1850] (+1000 pts) -> New Rank: #331 +89**
  - Also computes double-solve combination projections for multi-problem jumps (e.g. **• Solve [D + E] (+2500 pts) -> New Rank: #142 +148**).
- **Interactive Controls inside the HUD:**
  - `<CR>` or `o`: Instantly opens the selected problem statement in your web browser.
  - `r`: Refresh contest standings and rating predictions immediately (bypasses cache).
  - `s`: Switch or update your Codeforces handle.
  - `q` or `<Esc>`: Close the HUD.

#### Live Standings & Elo HUD Preview
Pressing `<leader>rl` opens a floating real-time dashboard:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Codeforces Round 1010 (Div. 2)                                         │
│ 📡 Phase: CODING (LIVE CONTEST RUNNING!)                               │
│ 📅 Date: 2026-10-30 (today)                                            │
│ 📊 Standing: Rank #1591 (#1290) | Points: 2244 | Solved: 3/7           │
│ 📈 Projected Delta: 1861 -> 1885  +24 (+239 needed to CM)              │
│ ✨ GUARANTEED CANDIDATE MASTER AFTER THIS CONTEST! CONGRATS! ✨        │
├────────────────────────────────────────────────────────────────────────┤
│  Idx   Problem Name                 Solved  Diff     Pts     Status    │
├────────────────────────────────────────────────────────────────────────┤
│  [A]   Circuit Repair               14204   ~1100*   500     ✔ Solved  │
│  [B]   Permutation Graph            11850   ~1300*   1000    ✔ Solved  │
│  [C]   Tree Counting                4120    ~1550*   1500    ✔ Solved  │
│  [D]   Matrix Queries               890     ~1850*   2000    -         │
│  [E]   Subsequence Optimization     124     ~2300*   2500    -         │
├────────────────────────────────────────────────────────────────────────┤
│ 🎯 What-If Solve Projections:                                          │
│   • Solve [D] [1850] (+1000 pts) -> New Rank: #331   +89               │
│   • Solve [E] [2300] (+1500 pts) -> New Rank: #142   +148              │
├────────────────────────────────────────────────────────────────────────┤
│ [<CR>/o] Open Problem  [r] Refresh  [s] Change Handle  [q/Esc] Close   │
└────────────────────────────────────────────────────────────────────────┘
```

### 12. Codeforces Live Contest Timer (`<leader>rT`)
Press `<leader>rT` anytime during a live contest to view the remaining time and active coding status:
- **Live Contests (Coding Phase):** Displays remaining contest time with an active ASCII progress bar ticking down every second (**⏳ Time Remaining: 01:23:45 (42% elapsed)**).
- **Finished Contests:** Displays completed status and points you to live standings via `<leader>rl`.
- Upcoming contest countdowns have been intentionally removed to keep the interface minimal and focused strictly on the active round.
- Press `q` or `Esc` to close the floating timer anytime.

### 13. Meta Hacker Cup & USACO File Runner (`<leader>rm` / `<leader>rf`)
Meta Hacker Cup requires uploading generated `output.txt` files against large official inputs:
- **Automated Problem Separation:** Meta Hacker Cup problems fetched via Competitive Companion are automatically separated into dedicated directories: `~/cp/MetaHackerCup/<year>/<round>/problem<letter>/<stem>.cpp` via [`lua/plugins/competitest.lua`](lua/plugins/competitest.lua) and [`lua/config/cph_server.lua`](lua/config/cph_server.lua). This guarantees that `output.txt` for Problem B will never overwrite `output.txt` from Problem A.
- **1-Click File Picker & Shell Redirection (`<leader>rm` / `<leader>rf`):** Press `<leader>rm` (or `<leader>rf`) to open your `~/Downloads` folder directly in Snacks file picker via [`lua/config/file_runner.lua`](lua/config/file_runner.lua). Select any downloaded input file and hit `<Enter>`:
  - Compiles your solution with `mold`.
  - Executes `./solution < input.txt > output.txt` using shell redirection (no code changes or manual copy-pasting needed!).
  - Automatically creates `output.txt` inside the problem folder even if it did not exist before.
  - Automatically copies the full absolute path of `output.txt` to your system clipboard (`+` register) for instant pasting into Meta's web upload form.
  - Opens `output.txt` in a vertical split beside your code for immediate visual verification.
- **Default Commented File I/O in Templates & Snippets:** Both [`templates/cp_template.cpp`](templates/cp_template.cpp) and algorithm snippets include commented file redirection lines (`// freopen("input.txt", "r", stdin);` / `// freopen("output.txt", "w", stdout);`). They introduce zero runtime or compilation overhead when commented, and are ready whenever local file-based testing is preferred.

### 14. GitHub Copilot & Contest Mode (`<leader>t`)
GitHub Copilot is integrated with native inline ghost text across all programming languages (C++, Python, TypeScript, Java, HTML). It is decoupled from the popup menu, leaving snippets and standard 2-space `<Tab>` untouched.
- **Default State:** Copilot starts **disabled by default** on Neovim startup to comply with Codeforces anti-cheat rules. Press **`<leader>tc`** to toggle Copilot on or off anytime.

<details>
<summary><b>View GitHub Copilot Keybindings & Controls (Click to Expand)</b></summary>

- `<leader>tc` -> Master Contest Mode switch (turns Copilot completely off during rated contests to comply with anti-cheat rules, press again to re-enable)
- `<leader>ta` -> Toggle Auto-Trigger (switches between continuous inline ghost text and on-demand mode)
- `<leader>tr` -> Request suggestion manually (blocked automatically with a warning if Contest Mode is active)
- `<leader>ts` -> View Copilot connection and auth status
- `<leader>tp` -> Open suggestions panel with 10 alternative completions
- `<leader>tl` -> Log in via GitHub device flow (copies code to clipboard)
- `<leader>to` -> Log out and clear session tokens
- `Alt + l` -> Accept entire ghost suggestion
- `Alt + w` -> Accept next word
- `Alt + j` -> Accept next line
- `Alt + ]` / `Alt + [` -> Cycle next or previous suggestion
- `Ctrl + ]` -> Dismiss suggestion

</details>

### 15. Editor Ergonomics & Visual Customizations
- **2-Second Idle Auto-Save:** Pausing typing for 2 seconds automatically saves the buffer in the background without interrupting your typing or shifting cursor position.
- **Typo Protection:** Aliased common Shift-typo commands (`:Q` -> `:q`, `:Qa` -> `:qa`, `:W` -> `:w`, `:Wq` -> `:wq`, `:Wa` -> `:wa`).
- **Hybrid Line Numbers:** Active cursor line displays its actual line number, while lines above and below count upward 1, 2, 3... for fast vertical jumping (`15j`, `8k`).
- **Statusline (Bottom-Right):** Displays buffer progress percentage (**Top** / **45%** / **Bot**) alongside cursor position and total file size: `45% Ln %d, Col %d / %d lines`.

---

<a id="keymaps"></a>
## Keymap Reference

<details>
<summary><b>View Full Keymap Reference Table (Click to Expand)</b></summary>

| Keymap | Action | Description |
|---|---|---|
| `<leader>rr` | **Run Testcases** | Compiles in ~0.32s and runs sample cases (press `q` to close) |
| `<leader>rd` / `<leader>rx` | **Run Local Debug** | Runs testcases with `dbg(...)`, `------`, and Chrono timing |
| `<leader>rb` | **Stress Test** | Automated loop (solution vs brute) until mismatch found |
| `<leader>rB` | **Open Brute** | Opens problem brute force (`<stem>_brute.cpp`) in a vertical split |
| `<leader>rG` | **Open Gen** | Opens problem generator (`<stem>_gen.cpp`) in a vertical split |
| `<leader>rz` | **Run Sanitizer** | Catches segfaults & out-of-bounds with exact line numbers |
| `<leader>ru` | **Open Problem URL** | Opens Codeforces problem statement in browser |
| `<leader>ra` | **Add Testcase** | Add a custom test case |
| `<leader>re` | **Edit Testcase** | Edit existing sample test cases |
| `<leader>rD` | **Delete Testcase** | Delete a testcase |
| `<leader>rs` | **Submit** | 3-step verification (comment dbg, syntax, ASan red-line jump) & submit |
| `<leader>rl` | **CF Standings & Predictor** | Live contest standings, Carrot rating prediction, and Repovive difficulty |
| `<leader>rc` | **Comment Debugs** | Comments out all active `dbg(...)` calls in the buffer |
| `<leader>rC` | **Uncomment Debugs** | Uncomments all `dbg(...)` calls in the buffer |
| `<leader>rk` | **Toggle Headless Submit** | Global privacy consent toggle (headless cookie submit vs browser fallback) |
| `<leader>rh` | **Health Check** | Pre-contest environment diagnostics (runs automatically when opening ~/cp) |
| `<leader>rT` | **Live Contest Timer** | Live Codeforces contest timer & ticking countdown HUD |
| `<leader>rm` / `<leader>rf` | **Meta Input Runner** | Pick input file from ~/Downloads, run with redirection, and auto-create output.txt |
| `<leader>rt` / `rt` | **Algorithm Picker** | Browse and insert CP algorithm snippets with live preview |
| `<leader>tc` | **Toggle Copilot** | Instantly enable/disable Copilot for contest rules |
| `<leader>ta` | **Toggle Auto-Trigger** | Toggle auto ghost text vs manual on-demand |
| `<leader>ts` | **Copilot Status** | View Copilot connection, auth, and model info |
| `<leader>tp` | **Copilot Panel** | Open 10 alternative completions split panel |
| `<leader>te` / `<leader>td` | **Enable / Disable** | Force enable or force disable Copilot |
| `<leader>tr` | **Trigger Suggestion** | Manually request Copilot inline suggestion |
| `<leader>tl` | **Copilot Login** | Initiate GitHub device code auth flow |
| `<leader>to` | **Copilot Logout** | Sign out of GitHub Copilot |
| `<M-l>` *(Insert)* | **Accept Suggestion** | Accept the entire inline ghost text |
| `<M-w>` *(Insert)* | **Accept Word** | Accept the next word of ghost text |
| `<M-j>` *(Insert)* | **Accept Line** | Accept the next line of ghost text |
| `<M-]>` / `<M-[>` | **Next / Prev** | Cycle between alternative suggestions |
| `<C-]>` *(Insert)* | **Dismiss** | Dismiss active ghost suggestion |
| `<leader>cf` | **Format Code** | Formats buffer with Google C++ Style |
| `<leader><leader>` | **Find Files** | Fuzzy find files across entire home directory |

</details>

---

<a id="cp-template"></a>
## Default Template (`cp_template.cpp`)

Here is the clean default template automatically injected into every new problem (compiles in **~0.27s** on ancient i5-4430 / **~70 to 80 ms** on modern CPUs):

<details>
<summary><b>View Default Template (cp_template.cpp)</b></summary>

```cpp
// Check my Neovim config at https://github.com/RustamSheoran/nvim
#include <bits/stdc++.h>
#include <cassert>

#if defined(__GNUC__) && defined(__x86_64__)
#pragma GCC optimize("O3,unroll-loops")
#pragma GCC target("avx2,bmi,bmi2,lzcnt,popcnt")
#endif

using namespace std;

// ==================== Type Aliases ====================
using ll   = long long;
using ull  = unsigned long long;
using ld   = long double;
using i128 = __int128_t;
using pii  = pair<int, int>;
using pll  = pair<ll, ll>;
using vi   = vector<int>;
using vll  = vector<ll>;
using vpii = vector<pii>;
using vpll = vector<pll>;
using vvi  = vector<vi>;
using vvll = vector<vll>;
template <class T> using min_pq = priority_queue<T, vector<T>, greater<T>>;

// ==================== Macros ====================
#define all(x)      (x).begin(), (x).end()
#define rall(x)     (x).rbegin(), (x).rend()
#define sz(x)       ((int)(x).size())
#define pb          push_back
#define eb          emplace_back
#define fi          first
#define se          second
#define mp          make_pair
#define sp          ' '
#define nl          '\n'

#define rep(i, n)        for (int i = 0; i < (n); ++i)
#define rep1(i, n)       for (int i = 1; i <= (n); ++i)
#define rrep(i, n)       for (int i = (n) - 1; i >= 0; --i)
#define forr(i, a, b)    for (int i = (a); i <= (b); ++i)
#define roff(i, a, b)    for (int i = (b); i >= (a); --i)
#define each(x, a)       for (auto &x : a)

// ==================== Constants & Both MODs ====================
const int MOD1 = 1e9 + 7;
const int MOD9 = 998244353;
const ll INFLL = 1e18;
const int INF  = 1e9 + 7;

// ==================== Grid Directions ====================
const int dx[4] = {1, 0, -1, 0};
const int dy[4] = {0, 1, 0, -1};

// ==================== chmin & chmax ====================
template <class T, class U = T>
bool chmin(T &a, U b) { if (b < a) { a = b; return true; } return false; }
template <class T, class U = T>
bool chmax(T &a, U b) { if (a < b) { a = b; return true; } return false; }

// ==================== Loopless Stream I/O ====================
template <class T1, class T2>
istream &operator>>(istream &is, pair<T1, T2> &p) { return is >> p.fi >> p.se; }
template <class T1, class T2>
ostream &operator<<(ostream &os, const pair<T1, T2> &p) { return os << p.fi << ' ' << p.se; }

template <class T>
istream &operator>>(istream &is, vector<T> &v) { for (auto &x : v) is >> x; return is; }
template <class T>
ostream &operator<<(ostream &os, const vector<T> &v) {
    for (int i = 0; i < sz(v); ++i) { if (i) os << ' '; os << v[i]; }
    return os;
}

// 0-indexing shortcuts (e.g. cin >> edge; --edge;)
template <class T1, class T2>
pair<T1, T2> &operator--(pair<T1, T2> &p) { --p.fi; --p.se; return p; }
template <class T>
vector<T> &operator--(vector<T> &v) { for (auto &x : v) --x; return v; }

// ==================== Debug Macro ====================
#ifdef DEBUG
void _dbg_out() { cerr << "\n"; }
template <typename Head, typename... Tail>
void _dbg_out(Head H, Tail... T) {
    cerr << H;
    if (sizeof...(T)) cerr << " | ";
    _dbg_out(T...);
}
#define dbg(...) cerr << "[" << #__VA_ARGS__ << "]: ", _dbg_out(__VA_ARGS__)
#else
#define dbg(...) 42
#endif

// ==================== Solution ====================
void solve() {
    
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    // Meta Hacker Cup / USACO file I/O (uncomment to redirect; creates output.txt automatically):
    // freopen("input.txt", "r", stdin);
    // freopen("output.txt", "w", stdout);

    int t = 1;
    cin >> t;
#ifdef LOCAL
    auto _start = chrono::high_resolution_clock::now();
    for (int tc = 1; tc <= t; ++tc) {
        cout << "------\n";
        solve();
    }
    cout << "------\n";
    auto _end = chrono::high_resolution_clock::now();
    chrono::duration<double, milli> _elapsed = _end - _start;
    cerr << fixed << setprecision(2) << "\n[Time: " << _elapsed.count() << " ms]\n";
#else
    while (t--) solve();
#endif
}
```
</details>

## Full Library Template (`cpp_template.cpp`)

Your complete algorithm library template is stored in [`templates/cpp_template.cpp`](templates/cpp_template.cpp) and remains accessible anytime via the `cpp` snippet:

<details>
<summary>View cpp_template.cpp (Full Library)</summary>

```cpp
#include <bits/stdc++.h>
using namespace std;

// Types
using ll = long long;
using vi = vector<int>;
using vll = vector<ll>;

// Macros
#define PB push_back
#define popb pop_back
#define nl '\n'
#define sp ' '
#define all(x) x.begin(), x.end()

// Constants
const int INF = 1e9;
const ll INFLL = 1e18;
const ll MOD = 1e9 + 7;

// I/O
template <class T> istream &operator>>(istream &input, vector<T> &values) {
  for (T &value : values)
    input >> value;
  return input;
}

template <class T>
ostream &operator<<(ostream &output, const vector<T> &values) {
  for (int index = 0; index < (int)values.size(); index++) {
    if (index)
      output << ' ';
    output << values[index];
  }
  return output;
}

// Math Helpers
ll gcd(ll a, ll b) {
  while (b) {
    a %= b;
    swap(a, b);
  }
  return a;
}

ll lcm(ll a, ll b) { return a / gcd(a, b) * b; }

ll mod_add(ll a, ll b, ll mod = MOD) { return (a % mod + b % mod) % mod; }

ll mod_sub(ll a, ll b, ll mod = MOD) { return (a % mod - b % mod + mod) % mod; }

ll mod_mul(ll a, ll b, ll mod = MOD) {
  return (__int128)(a % mod) * (b % mod) % mod;
}

ll binpow(ll a, ll b, ll mod = MOD) {
  a %= mod;
  ll res = 1;
  while (b) {
    if (b & 1)
      res = mod_mul(res, a, mod);
    a = mod_mul(a, a, mod);
    b >>= 1;
  }
  return res;
}

bool isPrime(ll n) {
  if (n < 2)
    return false;
  for (ll p : {2, 3, 5, 7, 11, 13, 17, 19, 23, 29})
    if (n % p == 0)
      return n == p;

  ll d = n - 1;
  int s = 0;
  while ((d & 1) == 0)
    d >>= 1, s++;

  for (ll a : {2, 325, 9375, 28178, 450775, 9780504, 1795265022}) {
    if (a % n == 0)
      continue;
    ll x = binpow(a, d, n);
    if (x == 1 || x == n - 1)
      continue;
    bool composite = true;
    for (int i = 1; i < s; i++) {
      x = mod_mul(x, x, n);
      if (x == n - 1) {
        composite = false;
        break;
      }
    }
    if (composite)
      return false;
  }
  return true;
}

struct DSU {
  vi parent, size;
  DSU(int n = 0) { init(n); }
  void init(int n) {
    parent.resize(n);
    iota(parent.begin(), parent.end(), 0);
    size.assign(n, 1);
  }
  int find(int vertex) {
    return parent[vertex] == vertex ? vertex
                                    : parent[vertex] = find(parent[vertex]);
  }
  bool merge(int first, int second) {
    first = find(first);
    second = find(second);
    if (first == second)
      return false;
    if (size[first] < size[second])
      swap(first, second);
    parent[second] = first;
    size[first] += size[second];
    return true;
  }
  int component_size(int vertex) { return size[find(vertex)]; }
};

struct RollbackDSU {
  vi parent, size;
  vector<pair<int, int>> history;
  RollbackDSU(int n = 0) { init(n); }
  void init(int n) {
    parent.resize(n);
    iota(parent.begin(), parent.end(), 0);
    size.assign(n, 1);
    history.clear();
  }
  int find(int vertex) const {
    while (parent[vertex] != vertex)
      vertex = parent[vertex];
    return vertex;
  }
  int snapshot() const { return (int)history.size(); }
  bool merge(int first, int second) {
    first = find(first);
    second = find(second);
    if (first == second) {
      history.PB({-1, -1});
      return false;
    }
    if (size[first] < size[second])
      swap(first, second);
    history.PB({second, size[first]});
    parent[second] = first;
    size[first] += size[second];
    return true;
  }
  void rollback(int snapshot_size) {
    while ((int)history.size() > snapshot_size) {
      auto [child, old_size] = history.back();
      history.popb();
      if (child != -1) {
        int root = parent[child];
        size[root] = old_size;
        parent[child] = child;
      }
    }
  }
};

struct WeightedDSU {
  vi parent, size;
  vll potential;
  WeightedDSU(int n = 0) { init(n); }
  void init(int n) {
    parent.resize(n);
    iota(parent.begin(), parent.end(), 0);
    size.assign(n, 1);
    potential.assign(n, 0);
  }
  pair<int, ll> find(int vertex) {
    if (parent[vertex] == vertex)
      return {vertex, 0};
    auto [root, value] = find(parent[vertex]);
    potential[vertex] += value;
    parent[vertex] = root;
    return {root, potential[vertex]};
  }
  bool merge(int first, int second, ll difference) {
    auto [root_first, value_first] = find(first);
    auto [root_second, value_second] = find(second);
    if (root_first == root_second)
      return value_second - value_first == difference;
    if (size[root_first] < size[root_second]) {
      swap(root_first, root_second);
      swap(value_first, value_second);
      difference = -difference;
    }
    parent[root_second] = root_first;
    potential[root_second] = difference + value_first - value_second;
    size[root_first] += size[root_second];
    return true;
  }
  optional<ll> diff(int first, int second) {
    auto [root_first, value_first] = find(first);
    auto [root_second, value_second] = find(second);
    if (root_first != root_second)
      return nullopt;
    return value_second - value_first;
  }
};

template <class T> struct Fenwick {
  int n;
  vector<T> bit;
  Fenwick(int n_ = 0) { init(n_); }
  void init(int n_) {
    n = n_;
    bit.assign(n + 1, T{});
  }
  void build(const vector<T> &values) {
    init((int)values.size());
    for (int index = 0; index < n; index++) {
      bit[index + 1] += values[index];
      int next = index + 1 + ((index + 1) & -(index + 1));
      if (next <= n)
        bit[next] += bit[index + 1];
    }
  }
  void update(int index, T delta) {
    for (++index; index <= n; index += index & -index)
      bit[index] += delta;
  }
  T query(int right) const {
    T result{};
    for (; right > 0; right -= right & -right)
      result += bit[right];
    return result;
  }
  T query(int left, int right) const { return query(right) - query(left); }
  int lower_bound(T target) const {
    int index = 0;
    for (int step = 1 << bit_width((unsigned)n); step; step >>= 1)
      if (index + step <= n && bit[index + step] < target)
        target -= bit[index += step];
    return index;
  }
};

template <class T> struct Fenwick2D {
  int n, m;
  vector<vector<T>> bit;
  Fenwick2D(int n_ = 0, int m_ = 0) { init(n_, m_); }
  void init(int n_, int m_) {
    n = n_;
    m = m_;
    bit.assign(n + 1, vector<T>(m + 1));
  }
  void update(int row, int column, T delta) {
    for (++row; row <= n; row += row & -row)
      for (int current = column + 1; current <= m;
           current += current & -current)
        bit[row][current] += delta;
  }
  T query(int row, int column) const {
    T result{};
    for (; row > 0; row -= row & -row)
      for (int current = column; current > 0; current -= current & -current)
        result += bit[row][current];
    return result;
  }
  T query(int top, int left, int bottom, int right) const {
    return query(bottom, right) - query(top, right) - query(bottom, left) +
           query(top, left);
  }
};

template <class T, class Merge> struct IterativeSegmentTree {
  int n;
  T identity;
  Merge merge;
  vector<T> tree;
  IterativeSegmentTree(int n_, T identity_, Merge merge_)
      : identity(identity_), merge(merge_) {
    init(n_);
  }
  void init(int n_) {
    n = 1;
    while (n < n_)
      n <<= 1;
    tree.assign(2 * n, identity);
  }
  void build(const vector<T> &values) {
    init((int)values.size());
    for (int index = 0; index < (int)values.size(); index++)
      tree[n + index] = values[index];
    for (int index = n - 1; index; index--)
      tree[index] = merge(tree[index << 1], tree[index << 1 | 1]);
  }
  void update(int index, T value) {
    for (tree[index += n] = value; index >>= 1;)
      tree[index] = merge(tree[index << 1], tree[index << 1 | 1]);
  }
  T query(int left, int right) const {
    T first = identity, second = identity;
    for (left += n, right += n; left < right; left >>= 1, right >>= 1) {
      if (left & 1)
        first = merge(first, tree[left++]);
      if (right & 1)
        second = merge(tree[--right], second);
    }
    return merge(first, second);
  }
};

struct LazySegmentTree {
  int n;
  vll tree, lazy;
  LazySegmentTree(int n_ = 0) { init(n_); }
  void init(int n_) {
    n = n_;
    tree.assign(4 * max(1, n), 0);
    lazy.assign(4 * max(1, n), 0);
  }
  void build(const vll &values) {
    init((int)values.size());
    if (n)
      build(1, 0, n, values);
  }
  void build(int node, int left, int right, const vll &values) {
    if (right - left == 1) {
      tree[node] = values[left];
      return;
    }
    int middle = (left + right) / 2;
    build(node << 1, left, middle, values);
    build(node << 1 | 1, middle, right, values);
    pull(node);
  }
  void apply(int node, int left, int right, ll value) {
    tree[node] += value * (right - left);
    lazy[node] += value;
  }
  void push(int node, int left, int right) {
    if (lazy[node] == 0 || right - left == 1)
      return;
    int middle = (left + right) / 2;
    apply(node << 1, left, middle, lazy[node]);
    apply(node << 1 | 1, middle, right, lazy[node]);
    lazy[node] = 0;
  }
  void pull(int node) { tree[node] = tree[node << 1] + tree[node << 1 | 1]; }
  void update(int left, int right, ll value) {
    update(1, 0, n, left, right, value);
  }
  void update(int node, int start, int finish, int left, int right, ll value) {
    if (right <= start || finish <= left)
      return;
    if (left <= start && finish <= right) {
      apply(node, start, finish, value);
      return;
    }
    push(node, start, finish);
    int middle = (start + finish) / 2;
    update(node << 1, start, middle, left, right, value);
    update(node << 1 | 1, middle, finish, left, right, value);
    pull(node);
  }
  ll query(int left, int right) { return query(1, 0, n, left, right); }
  ll query(int node, int start, int finish, int left, int right) {
    if (right <= start || finish <= left)
      return 0;
    if (left <= start && finish <= right)
      return tree[node];
    push(node, start, finish);
    int middle = (start + finish) / 2;
    return query(node << 1, start, middle, left, right) +
           query(node << 1 | 1, middle, finish, left, right);
  }
};

template <class T, class Merge> struct SparseTable {
  vector<vector<T>> table;
  Merge merge;
  SparseTable(const vector<T> &values, Merge merge_) : merge(merge_) {
    build(values);
  }
  void build(const vector<T> &values) {
    int n = (int)values.size();
    table.assign(bit_width((unsigned)max(1, n)), vector<T>(n));
    if (!n)
      return;
    table[0] = values;
    for (int level = 1; (1 << level) <= n; level++)
      for (int index = 0; index + (1 << level) <= n; index++)
        table[level][index] = merge(table[level - 1][index],
                                    table[level - 1][index + (level - 1)]);
  }
  T query(int left, int right) const {
    int level = bit_width((unsigned)(right - left)) - 1;
    return merge(table[level][left], table[level][right - (1 << level)]);
  }
};

struct LiChaoTree {
  struct Line {
    ll slope = 0, intercept = INFLL;
    ll value(ll x) const { return slope * x + intercept; }
  };
  ll left, right;
  vector<Line> tree;
  vector<bool> used;
  LiChaoTree(ll left_, ll right_)
      : left(left_), right(right_), tree(4), used(4, false) {}
  void add_line(Line line) { add_line(1, left, right, line); }
  void add_line(int node, ll start, ll finish, Line line) {
    if ((int)tree.size() <= node) {
      tree.resize(2 * node + 1);
      used.resize(2 * node + 1);
    }
    if (!used[node]) {
      tree[node] = line;
      used[node] = true;
      return;
    }
    ll middle = start + (finish - start) / 2;
    bool low = line.value(start) < tree[node].value(start),
         mid = line.value(middle) < tree[node].value(middle);
    if (mid)
      swap(line, tree[node]);
    if (start == finish)
      return;
    if (low != mid)
      add_line(node << 1, start, middle, line);
    else
      add_line(node << 1 | 1, middle + 1, finish, line);
  }
  ll query(ll x) const { return query(1, left, right, x); }
  ll query(int node, ll start, ll finish, ll x) const {
    if (node >= (int)tree.size())
      return INFLL;
    ll result = used[node] ? tree[node].value(x) : INFLL;
    if (start == finish)
      return result;
    ll middle = start + (finish - start) / 2;
    return min(result, x <= middle
                           ? query(node << 1, start, middle, x)
                           : query(node << 1 | 1, middle + 1, finish, x));
  }
};

vi bfs(const vector<vi> &graph, int source) {
  vi distance(graph.size(), INF);
  queue<int> queue;
  distance[source] = 0;
  queue.push(source);
  while (!queue.empty()) {
    int vertex = queue.front();
    queue.pop();
    for (int next : graph[vertex])
      if (distance[next] == INF)
        distance[next] = distance[vertex] + 1, queue.push(next);
  }
  return distance;
}

vi zero_one_bfs(const vector<vector<pair<int, int>>> &graph, int source) {
  vi distance(graph.size(), INF);
  deque<int> queue;
  distance[source] = 0;
  queue.push_back(source);
  while (!queue.empty()) {
    int vertex = queue.front();
    queue.pop_front();
    for (auto [next, weight] : graph[vertex])
      if (distance[next] > distance[vertex] + weight) {
        distance[next] = distance[vertex] + weight;
        if (weight)
          queue.push_back(next);
        else
          queue.push_front(next);
      }
  }
  return distance;
}

vll dijkstra(const vector<vector<pair<int, ll>>> &graph, int source) {
  vll distance(graph.size(), INFLL);
  priority_queue<pair<ll, int>, vector<pair<ll, int>>, greater<>> queue;
  distance[source] = 0;
  queue.push({0, source});
  while (!queue.empty()) {
    auto [current, vertex] = queue.top();
    queue.pop();
    if (current != distance[vertex])
      continue;
    for (auto [next, weight] : graph[vertex])
      if (distance[next] > current + weight)
        queue.push({distance[next] = current + weight, next});
  }
  return distance;
}

vi iterative_dfs_order(const vector<vi> &graph, int source) {
  vi order, seen(graph.size());
  vector<int> stack = {source};
  while (!stack.empty()) {
    int vertex = stack.back();
    stack.popb();
    if (seen[vertex])
      continue;
    seen[vertex] = 1;
    order.PB(vertex);
    for (auto it = graph[vertex].rbegin(); it != graph[vertex].rend(); ++it)
      if (!seen[*it])
        stack.PB(*it);
  }
  return order;
}

optional<vi> topological_sort(const vector<vi> &graph) {
  int n = (int)graph.size();
  vi degree(n), order;
  for (const auto &edges : graph)
    for (int next : edges)
      degree[next]++;
  queue<int> queue;
  for (int vertex = 0; vertex < n; vertex++)
    if (!degree[vertex])
      queue.push(vertex);
  while (!queue.empty()) {
    int vertex = queue.front();
    queue.pop();
    order.PB(vertex);
    for (int next : graph[vertex])
      if (!--degree[next])
        queue.push(next);
  }
  if ((int)order.size() != n)
    return nullopt;
  return order;
}

bool has_directed_cycle(const vector<vi> &graph) {
  vi state(graph.size());
  auto dfs = [&](auto &&self, int vertex) -> bool {
    state[vertex] = 1;
    for (int next : graph[vertex]) {
      if (state[next] == 1)
        return true;
      if (!state[next] && self(self, next))
        return true;
    }
    state[vertex] = 2;
    return false;
  };
  for (int vertex = 0; vertex < (int)graph.size(); vertex++)
    if (!state[vertex] && dfs(dfs, vertex))
      return true;
  return false;
}

struct Edge {
  int from, to;
  ll weight;
};

pair<vll, bool> bellman_ford(int n, const vector<Edge> &edges, int source) {
  vll distance(n, INFLL);
  distance[source] = 0;
  for (int iteration = 0; iteration < n; iteration++) {
    bool changed = false;
    for (auto [from, to, weight] : edges)
      if (distance[from] != INFLL && distance[to] > distance[from] + weight)
        distance[to] = max(-INFLL, distance[from] + weight), changed = true;
    if (!changed)
      return {distance, false};
  }
  return {distance, true};
}

vector<vll> floyd_warshall(vector<vll> distance) {
  for (int middle = 0; middle < (int)distance.size(); middle++)
    for (int from = 0; from < (int)distance.size(); from++)
      if (distance[from][middle] != INFLL)
        for (int to = 0; to < (int)distance.size(); to++)
          if (distance[middle][to] != INFLL)
            distance[from][to] =
                min(distance[from][to],
                    distance[from][middle] + distance[middle][to]);
  return distance;
}

pair<ll, vector<Edge>> kruskal(int n, vector<Edge> edges) {
  sort(edges.begin(), edges.end(), [](const Edge &first, const Edge &second) {
    return first.weight < second.weight;
  });
  DSU dsu(n);
  ll cost = 0;
  vector<Edge> tree;
  for (const Edge &edge : edges)
    if (dsu.merge(edge.from, edge.to))
      cost += edge.weight, tree.PB(edge);
  return {cost, tree};
}

pair<ll, vi> prim(const vector<vector<pair<int, ll>>> &graph, int source = 0) {
  int n = (int)graph.size();
  vll distance(n, INFLL);
  vi parent(n, -1);
  priority_queue<pair<ll, int>, vector<pair<ll, int>>, greater<>> queue;
  distance[source] = 0;
  queue.push({0, source});
  ll cost = 0;
  while (!queue.empty()) {
    auto [weight, vertex] = queue.top();
    queue.pop();
    if (weight != distance[vertex])
      continue;
    cost += weight;
    for (auto [next, edge_weight] : graph[vertex])
      if (distance[next] > edge_weight)
        queue.push({distance[next] = edge_weight, next}), parent[next] = vertex;
  }
  return {cost, parent};
}

struct TarjanSCC {
  vi index, low, component, stack;
  vector<bool> in_stack;
  int timer = 0, components = 0;
  void run(const vector<vi> &graph) {
    int n = (int)graph.size();
    index.assign(n, -1);
    low.resize(n);
    component.assign(n, -1);
    in_stack.assign(n, false);
    auto dfs = [&](auto &&self, int vertex) -> void {
      index[vertex] = low[vertex] = timer++;
      stack.PB(vertex);
      in_stack[vertex] = true;
      for (int next : graph[vertex]) {
        if (index[next] == -1)
          self(self, next), low[vertex] = min(low[vertex], low[next]);
        else if (in_stack[next])
          low[vertex] = min(low[vertex], index[next]);
      }
      if (low[vertex] == index[vertex]) {
        while (true) {
          int next = stack.back();
          stack.popb();
          in_stack[next] = false;
          component[next] = components;
          if (next == vertex)
            break;
        }
        components++;
      }
    };
    for (int vertex = 0; vertex < n; vertex++)
      if (index[vertex] == -1)
        dfs(dfs, vertex);
  }
};

struct LCA {
  int log;
  vi depth;
  vector<vi> up;
  LCA(const vector<vi> &tree, int root = 0) {
    int n = (int)tree.size();
    log = bit_width((unsigned)max(1, n));
    depth.assign(n, 0);
    up.assign(log, vi(n, root));
    vector<int> parent(n, root), order = {root};
    for (int index = 0; index < (int)order.size(); index++)
      for (int next : tree[order[index]])
        if (next != parent[order[index]])
          parent[next] = order[index], depth[next] = depth[order[index]] + 1,
          order.PB(next);
    up[0] = parent;
    for (int level = 1; level < log; level++)
      for (int vertex = 0; vertex < n; vertex++)
        up[level][vertex] = up[level - 1][up[level - 1][vertex]];
  }
  int jump(int vertex, int steps) const {
    for (int level = 0; steps; level++, steps >>= 1)
      if (steps & 1)
        vertex = up[level][vertex];
    return vertex;
  }
  int query(int first, int second) const {
    if (depth[first] < depth[second])
      swap(first, second);
    first = jump(first, depth[first] - depth[second]);
    if (first == second)
      return first;
    for (int level = log - 1; level >= 0; level--)
      if (up[level][first] != up[level][second])
        first = up[level][first], second = up[level][second];
    return up[0][first];
  }
};

struct Dinic {
  struct FlowEdge {
    int to, reverse;
    ll capacity;
  };
  int n;
  vector<vector<FlowEdge>> graph;
  vi level, pointer;
  Dinic(int n_) : n(n_), graph(n), level(n), pointer(n) {}
  void add_edge(int from, int to, ll capacity) {
    FlowEdge forward{to, (int)graph[to].size(), capacity},
        backward{from, (int)graph[from].size(), 0};
    graph[from].PB(forward);
    graph[to].PB(backward);
  }
  bool bfs(int source, int sink) {
    fill(level.begin(), level.end(), -1);
    queue<int> queue;
    level[source] = 0;
    queue.push(source);
    while (!queue.empty()) {
      int vertex = queue.front();
      queue.pop();
      for (const auto &edge : graph[vertex])
        if (edge.capacity && level[edge.to] == -1)
          level[edge.to] = level[vertex] + 1, queue.push(edge.to);
    }
    return level[sink] != -1;
  }
  ll dfs(int vertex, int sink, ll pushed) {
    if (!pushed || vertex == sink)
      return pushed;
    for (int &edge_index = pointer[vertex];
         edge_index < (int)graph[vertex].size(); edge_index++) {
      FlowEdge &edge = graph[vertex][edge_index];
      if (level[edge.to] != level[vertex] + 1 || !edge.capacity)
        continue;
      ll flow = dfs(edge.to, sink, min(pushed, edge.capacity));
      if (flow) {
        edge.capacity -= flow;
        graph[edge.to][edge.reverse].capacity += flow;
        return flow;
      }
    }
    return 0;
  }
  ll max_flow(int source, int sink) {
    ll result = 0;
    while (bfs(source, sink)) {
      fill(pointer.begin(), pointer.end(), 0);
      while (ll flow = dfs(source, sink, INFLL))
        result += flow;
    }
    return result;
  }
};

vi prefix_function(const string &text) {
  vi pi(text.size());
  for (int index = 1; index < (int)text.size(); index++) {
    int border = pi[index - 1];
    while (border && text[index] != text[border])
      border = pi[border - 1];
    if (text[index] == text[border])
      border++;
    pi[index] = border;
  }
  return pi;
}

vi kmp_find(const string &text, const string &pattern) {
  if (pattern.empty())
    return {};
  vi pi = prefix_function(pattern + '\0' + text), positions;
  for (int index = (int)pattern.size() + 1; index < (int)pi.size(); index++)
    if (pi[index] == (int)pattern.size())
      positions.PB(index - 2 * (int)pattern.size());
  return positions;
}

vi z_function(const string &text) {
  int n = (int)text.size(), left = 0, right = 0;
  vi z(n);
  for (int index = 1; index < n; index++) {
    if (index < right)
      z[index] = min(right - index, z[index - left]);
    while (index + z[index] < n && text[z[index]] == text[index + z[index]])
      z[index]++;
    if (index + z[index] > right)
      left = index, right = index + z[index];
  }
  if (n)
    z[0] = n;
  return z;
}

struct Trie {
  struct Node {
    array<int, 26> next{};
    int count = 0, ending = 0;
    Node() { next.fill(-1); }
  };
  vector<Node> nodes = {Node()};
  void insert(const string &word) {
    int vertex = 0;
    for (char character : word) {
      int index = character - 'a';
      if (nodes[vertex].next[index] == -1)
        nodes[vertex].next[index] = (int)nodes.size(), nodes.PB(Node());
      vertex = nodes[vertex].next[index];
      nodes[vertex].count++;
    }
    nodes[vertex].ending++;
  }
  int count_prefix(const string &prefix) const {
    int vertex = 0;
    for (char character : prefix) {
      vertex = nodes[vertex].next[character - 'a'];
      if (vertex == -1)
        return 0;
    }
    return nodes[vertex].count;
  }
  bool contains(const string &word) const {
    int vertex = 0;
    for (char character : word) {
      vertex = nodes[vertex].next[character - 'a'];
      if (vertex == -1)
        return false;
    }
    return nodes[vertex].ending > 0;
  }
};

pair<vi, vi> manacher(const string &text) {
  int n = (int)text.size();
  vi odd(n), even(n);
  for (int type = 0; type < 2; type++) {
    vi &radius = type ? even : odd;
    int left = 0, right = -1;
    for (int index = 0; index < n; index++) {
      int value = index > right ? 0
                                : min(radius[left + right - index + type],
                                      right - index + 1);
      while (index + value < n && index - value - 1 + type >= 0 &&
             text[index + value] == text[index - value - 1 + type])
        value++;
      radius[index] = value;
      if (index + value - 1 > right)
        left = index - value + type, right = index + value - 1;
    }
  }
  return {odd, even};
}

ll extended_gcd(ll first, ll second, ll &x, ll &y) {
  if (!second)
    return x = 1, y = 0, first;
  ll gcd_value = extended_gcd(second, first % second, y, x);
  y -= first / second * x;
  return gcd_value;
}

optional<pair<ll, ll>> crt(ll first_remainder, ll first_modulus,
                           ll second_remainder, ll second_modulus) {
  ll x, y, divisor = extended_gcd(first_modulus, second_modulus, x, y);
  if ((second_remainder - first_remainder) % divisor)
    return nullopt;
  ll lcm_value = first_modulus / divisor * second_modulus;
  ll value = (first_remainder + (__int128)(second_remainder - first_remainder) /
                                    divisor * x % (second_modulus / divisor) *
                                    first_modulus) %
             lcm_value;
  if (value < 0)
    value += lcm_value;
  return {{value, lcm_value}};
}

vi linear_sieve(int limit) {
  vi least_prime(limit + 1), primes;
  for (int value = 2; value <= limit; value++) {
    if (!least_prime[value])
      least_prime[value] = value, primes.PB(value);
    for (int prime : primes) {
      if (prime > least_prime[value] || value * prime > limit)
        break;
      least_prime[value * prime] = prime;
    }
  }
  return least_prime;
}

ll euler_phi(ll value) {
  ll result = value;
  for (ll divisor = 2; divisor * divisor <= value; divisor++)
    if (value % divisor == 0) {
      while (value % divisor == 0)
        value /= divisor;
      result -= result / divisor;
    }
  if (value > 1)
    result -= result / value;
  return result;
}

vector<pair<ll, int>> prime_factorization(ll value) {
  vector<pair<ll, int>> factors;
  for (ll divisor = 2; divisor * divisor <= value; divisor += 1 + (divisor > 2))
    if (value % divisor == 0) {
      int count = 0;
      while (value % divisor == 0)
        value /= divisor, count++;
      factors.PB({divisor, count});
    }
  if (value > 1)
    factors.PB({value, 1});
  return factors;
}

template <class T> vi coordinate_compress(vector<T> &values) {
  vector<T> sorted = values;
  sort(sorted.begin(), sorted.end());
  sorted.erase(unique(sorted.begin(), sorted.end()), sorted.end());
  vi result(values.size());
  for (int index = 0; index < (int)values.size(); index++)
    result[index] = lower_bound(sorted.begin(), sorted.end(), values[index]) -
                    sorted.begin();
  values = move(sorted);
  return result;
}

template <class T> vector<T> prefix_sum(const vector<T> &values) {
  vector<T> prefix(values.size() + 1);
  for (int index = 0; index < (int)values.size(); index++)
    prefix[index + 1] = prefix[index] + values[index];
  return prefix;
}

template <class T>
vector<T> difference_array(int n, const vector<tuple<int, int, T>> &updates) {
  vector<T> difference(n + 1);
  for (auto [left, right, value] : updates)
    difference[left] += value, difference[right] -= value;
  for (int index = 1; index < n; index++)
    difference[index] += difference[index - 1];
  difference.popb();
  return difference;
}

void solve() {}

int main() {
  ios::sync_with_stdio(false);
  cin.tie(nullptr);

  int t = 1;
  cin >> t;

  while (t--)
    solve();
}
```
</details>

## Note for Omarchy Users
If you are running Omarchy OS, this Neovim configuration is entirely independent of the OS config files. Omarchy updates will never touch your `~/.config/nvim/` folder, so keeping your config backed up on GitHub guarantees your CP setup is always safe.
