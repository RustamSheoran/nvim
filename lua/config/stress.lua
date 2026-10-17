local M = {}

function M.get_paths(file)
  local dir = vim.fn.fnamemodify(file, ":h")
  local filename = vim.fn.fnamemodify(file, ":t")
  local name_no_ext = vim.fn.fnamemodify(filename, ":r")

  local stem = name_no_ext

  -- If currently inside a brute or gen file, extract the base problem stem
  local match_suffix_brute = name_no_ext:match("^(.*)_brute$")
  local match_suffix_gen = name_no_ext:match("^(.*)_gen$")
  local match_prefix_brute = name_no_ext:match("^brute_(.*)$")
  local match_prefix_gen = name_no_ext:match("^gen_(.*)$")

  if match_suffix_brute and match_suffix_brute ~= "" then
    stem = match_suffix_brute
  elseif match_suffix_gen and match_suffix_gen ~= "" then
    stem = match_suffix_gen
  elseif match_prefix_brute and match_prefix_brute ~= "" then
    stem = match_prefix_brute
  elseif match_prefix_gen and match_prefix_gen ~= "" then
    stem = match_prefix_gen
  elseif name_no_ext == "brute" or name_no_ext == "gen" then
    -- Fallback for legacy standalone brute.cpp or gen.cpp:
    local cpp_files = vim.fn.globpath(dir, "*.cpp", false, true)
    local candidates = {}
    for _, f in ipairs(cpp_files) do
      local fn = vim.fn.fnamemodify(f, ":t:r")
      if fn ~= "brute" and fn ~= "gen" and not fn:match("_brute$") and not fn:match("_gen$") and not fn:match("^brute_") and not fn:match("^gen_") then
        table.insert(candidates, fn)
      end
    end
    if #candidates == 1 then
      stem = candidates[1]
    end
  end

  local sol_file = dir .. "/" .. stem .. ".cpp"
  local sol_name = stem .. ".cpp"

  -- Determine brute file: prefer existing <stem>_brute.cpp, then brute_<stem>.cpp, default to <stem>_brute.cpp
  local brute_file = dir .. "/" .. stem .. "_brute.cpp"
  local brute_name = stem .. "_brute.cpp"
  if vim.fn.filereadable(brute_file) == 0 and vim.fn.filereadable(dir .. "/brute_" .. stem .. ".cpp") == 1 then
    brute_file = dir .. "/brute_" .. stem .. ".cpp"
    brute_name = "brute_" .. stem .. ".cpp"
  end

  -- Determine gen file: prefer existing <stem>_gen.cpp, then gen_<stem>.cpp, default to <stem>_gen.cpp
  local gen_file = dir .. "/" .. stem .. "_gen.cpp"
  local gen_name = stem .. "_gen.cpp"
  if vim.fn.filereadable(gen_file) == 0 and vim.fn.filereadable(dir .. "/gen_" .. stem .. ".cpp") == 1 then
    gen_file = dir .. "/gen_" .. stem .. ".cpp"
    gen_name = "gen_" .. stem .. ".cpp"
  end

  return {
    dir = dir,
    stem = stem,
    sol_file = sol_file,
    sol_name = sol_name,
    brute_file = brute_file,
    brute_name = brute_name,
    gen_file = gen_file,
    gen_name = gen_name,
  }
end

function M.ensure_files(dir, stem)
  local paths = M.get_paths(dir .. "/" .. stem .. ".cpp")
  local brute_file = paths.brute_file
  local gen_file = paths.gen_file
  local created_any = false

  if vim.fn.filereadable(brute_file) == 0 then
    local template_path = vim.fn.expand("~/.config/nvim/templates/cp_template.cpp")
    local body = ""
    if vim.fn.filereadable(template_path) == 1 then
      local lines = vim.fn.readfile(template_path)
      body = table.concat(lines, "\n")
    else
      body = [[#include <bits/stdc++.h>
using namespace std;

void solve() {

}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    int t = 1;
    cin >> t;
    while (t--) solve();
}
]]
    end

    local brute_header = string.format([[// ============================================================================
// 💡 BRUTE FORCE SOLUTION (%s) for %s
// ============================================================================
// WHAT THIS FILE DOES:
//   This is your slow, simple, 100%% correct baseline solution for %s.
//   Your main solution (%s) will be tested against this file.
//
// HOW TO WRITE THIS:
//   1. DO NOT try to write an optimal O(N) or O(N log N) algorithm here!
//   2. Write the simplest, most brain-dead code possible:
//      - Nested loops (O(N^2) or O(N^3))
//      - Recursion / backtracking (O(2^N) or O(N!))
//      - Whatever is completely trivial and impossible to get wrong.
//   3. Implement your brute-force logic inside solve() below.
//
// WORKFLOW:
//   - Open with <leader>rB, write the brute logic, then save (:w or :q).
//   - Ensure %s produces random inputs (<leader>rG).
//   - In your main solution file, press <leader>rb to start stress testing!
// ============================================================================

]], paths.brute_name, paths.sol_name, paths.sol_name, paths.sol_name, paths.gen_name)

    local f = io.open(brute_file, "w")
    if f then
      f:write(brute_header .. body)
      f:close()
      created_any = true
    end
  end

  if vim.fn.filereadable(gen_file) == 0 then
    local f = io.open(gen_file, "w")
    if f then
      local gen_header = string.format([[// ============================================================================
// 🎲 RANDOM TESTCASE GENERATOR (%s) for %s
// ============================================================================
// WHAT THIS FILE DOES:
//   This script outputs small, random test inputs matching %s's format.
//   It feeds random tests to BOTH your solution (%s) and %s until they disagree.
//
// 💡 THE GOLDEN RULE OF STRESS TESTING:
//   KEEP INPUTS SMALL! (e.g. N = 2 to 5, numbers = 1 to 10).
//   - Small tests run in 0.001s so brute force won't time out.
//   - Most bugs happen on small edge cases (duplicates, zeros, N=2).
//   - Counterexamples with 4 numbers are 100x easier to read and debug!
//
// 📚 QUICK EXAMPLES (Copy & adapt into main() below):
//
//   Example 1: Array of N integers
//     int n = rand_int(2, 5);
//     cout << n << "\n";
//     auto a = rand_array(n, 1, 10);
//     for (int i = 0; i < n; ++i) cout << a[i] << (i + 1 == n ? "" : " ");
//     cout << "\n";
//
//   Example 2: Random String of characters (e.g. "abc")
//     int n = rand_int(3, 6);
//     cout << n << "\n";
//     cout << rand_string(n, "abc") << "\n";
//
//   Example 3: Random Tree with N-1 edges
//     int n = rand_int(3, 6);
//     cout << n << "\n";
//     for (auto [u, v] : rand_tree(n)) cout << u << " " << v << "\n";
//
//   Example 4: Random Permutation of 1..N
//     int n = rand_int(3, 6);
//     cout << n << "\n";
//     for (int x : rand_permutation(n)) cout << x << " ";
//     cout << "\n";
//
// WORKFLOW:
//   - Open with <leader>rG, adapt main() to the problem's input format, save (:q).
//   - In your main solution file, press <leader>rb to start stress testing!
// ============================================================================

]], paths.gen_name, paths.sol_name, paths.sol_name, paths.sol_name, paths.brute_name)

      local gen_body = [[#include <bits/stdc++.h>
using namespace std;

// High-quality 64-bit random generator
mt19937_64 rng(chrono::steady_clock::now().time_since_epoch().count());

// Helper generator functions:
// 1. Random integer in range [l, r]
long long rand_int(long long l, long long r) {
    return uniform_int_distribution<long long>(l, r)(rng);
}

// 2. Random array of n integers with values in [l, r]
vector<long long> rand_array(int n, long long l, long long r) {
    vector<long long> a(n);
    for (auto &x : a) x = rand_int(l, r);
    return a;
}

// 3. Random permutation of numbers 1..n
vector<int> rand_permutation(int n) {
    vector<int> p(n);
    iota(p.begin(), p.end(), 1);
    shuffle(p.begin(), p.end(), rng);
    return p;
}

// 4. Random string of length n using characters from charset
string rand_string(int n, string charset = "abcdefghijklmnopqrstuvwxyz") {
    string s = "";
    for (int i = 0; i < n; ++i) s += charset[rand_int(0, (int)charset.size() - 1)];
    return s;
}

// 5. Random connected tree of n vertices (1-indexed edges)
vector<pair<int, int>> rand_tree(int n) {
    vector<pair<int, int>> edges;
    for (int i = 2; i <= n; ++i) {
        edges.push_back({rand_int(1, i - 1), i});
    }
    auto p = rand_permutation(n);
    for (auto &e : edges) {
        e.first = p[e.first - 1];
        e.second = p[e.second - 1];
        if (rand_int(0, 1)) swap(e.first, e.second);
    }
    return edges;
}

// ============================================================================
// 👇 Write your testcase generation logic here:
// ============================================================================
int main() {
    int t = 1; // Number of testcases
    cout << t << "\n";

    int n = rand_int(2, 5); // Keep N small!
    cout << n << "\n";

    auto a = rand_array(n, 1, 10);
    for (int i = 0; i < n; ++i) {
        cout << a[i] << (i + 1 == n ? "" : " ");
    }
    cout << "\n";
}
]]
      f:write(gen_header .. gen_body)
      f:close()
      created_any = true
    end
  end

  return created_any
end

function M.open_brute()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Open a C++ file first!", vim.log.levels.WARN, { title = "Stress Test" })
    return
  end
  local paths = M.get_paths(file)
  M.ensure_files(paths.dir, paths.stem)

  -- If the brute file is already active in the current window, do nothing
  if vim.fn.expand("%:p") == paths.brute_file then
    vim.notify("Already viewing " .. paths.brute_name, vim.log.levels.INFO, { title = "Stress Test" })
    return
  end

  -- If already open in another window in the current tab, focus that window
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf) == paths.brute_file then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  vim.cmd("vsplit " .. vim.fn.fnameescape(paths.brute_file))
end

function M.open_gen()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Open a C++ file first!", vim.log.levels.WARN, { title = "Stress Test" })
    return
  end
  local paths = M.get_paths(file)
  M.ensure_files(paths.dir, paths.stem)

  -- If the gen file is already active in the current window, do nothing
  if vim.fn.expand("%:p") == paths.gen_file then
    vim.notify("Already viewing " .. paths.gen_name, vim.log.levels.INFO, { title = "Stress Test" })
    return
  end

  -- If already open in another window in the current tab, focus that window
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf) == paths.gen_file then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  vim.cmd("vsplit " .. vim.fn.fnameescape(paths.gen_file))
end

function M.run()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Open a C++ file to run stress testing!", vim.log.levels.WARN, { title = "Stress Test" })
    return
  end

  local paths = M.get_paths(file)
  local created_any = M.ensure_files(paths.dir, paths.stem)
  if created_any then
    vim.notify(
      string.format("Created %s and %s!\nUse <leader>rB and <leader>rG to view/edit them.", paths.brute_name, paths.gen_name),
      vim.log.levels.INFO,
      { title = "Stress Test" }
    )
    return
  end

  if vim.fn.filereadable(paths.sol_file) == 0 then
    vim.notify("Main solution file not found: " .. paths.sol_file, vim.log.levels.ERROR, { title = "Stress Test" })
    return
  end

  -- Auto-save all open buffers before testing
  vim.cmd("silent! wa")

  local stress_cmd = string.format([[
cd '%s' && bash -c '
ulimit -s 262144 2>/dev/null
echo -e "\033[1;34m=== COMPILING %s, %s, and %s ===\033[0m"
g++ -O2 -std=c++17 -fuse-ld=mold "%s" -o __sol || exit 1
g++ -O2 -std=c++17 -fuse-ld=mold "%s" -o __brute || exit 1
g++ -O2 -std=c++17 -fuse-ld=mold "%s" -o __gen || exit 1

echo -e "\033[1;32m=== STRESS TESTING %s (Press Ctrl+C to stop) ===\033[0m"
i=1
while true; do
    ./__gen > __in.txt
    ./__sol < __in.txt > __out_sol.txt
    ./__brute < __in.txt > __out_brute.txt

    if ! diff -w -q __out_sol.txt __out_brute.txt > /dev/null; then
        echo ""
        echo -e "\033[1;31m=========================================="
        echo -e "💥 MISMATCH FOUND ON TEST #$i!"
        echo -e "==========================================\033[0m"
        echo -e "\033[1;33m--- INPUT (__in.txt) ---\033[0m"
        cat __in.txt
        echo ""
        echo -e "\033[1;31m--- YOUR OUTPUT (__out_sol.txt) ---\033[0m"
        cat __out_sol.txt
        echo ""
        echo -e "\033[1;32m--- BRUTE OUTPUT (__out_brute.txt) ---\033[0m"
        cat __out_brute.txt
        echo -e "\033[1;31m==========================================\033[0m"
        read -p "Press Enter to exit..." dummy
        break
    fi

    if (( i %% 50 == 0 )); then
        echo -ne "Passed $i tests...\r"
    fi
    ((i++))
done
'
]], paths.dir, paths.sol_name, paths.brute_name, paths.gen_name, paths.sol_name, paths.brute_name, paths.gen_name, paths.sol_name)

  if Snacks and Snacks.terminal then
    Snacks.terminal.open(stress_cmd, {
      cwd = paths.dir,
      auto_close = true,
      win = {
        on_buf = function(self)
          vim.keymap.set("n", "<CR>", function()
            self:close()
          end, { buffer = self.buf, silent = true, desc = "Close terminal" })
          vim.keymap.set("n", "q", function()
            self:close()
          end, { buffer = self.buf, silent = true, desc = "Close terminal" })
        end,
      },
    })
  else
    vim.cmd("botright 15split | terminal " .. stress_cmd)
    local buf = vim.api.nvim_get_current_buf()
    vim.keymap.set("n", "<CR>", "<cmd>close<CR>", { buffer = buf, silent = true })
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
  end
end

return M
