local M = {}

function M.ensure_files(dir)
  local brute_file = dir .. "/brute.cpp"
  local gen_file = dir .. "/gen.cpp"
  local created_any = false

  if vim.fn.filereadable(brute_file) == 0 then
    local template_path = vim.fn.expand("~/.config/nvim/templates/cp_template.cpp")
    local content = ""
    if vim.fn.filereadable(template_path) == 1 then
      local lines = vim.fn.readfile(template_path)
      content = table.concat(lines, "\n")
    else
      content = [[#include <bits/stdc++.h>
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

    local f = io.open(brute_file, "w")
    if f then
      f:write(content)
      f:close()
      created_any = true
    end
  end

  if vim.fn.filereadable(gen_file) == 0 then
    local f = io.open(gen_file, "w")
    if f then
      f:write([[#include <bits/stdc++.h>
using namespace std;

// High-quality 64-bit random generator
mt19937_64 rng(chrono::steady_clock::now().time_since_epoch().count());

// Helper generator functions:
long long rand_int(long long l, long long r) {
    return uniform_int_distribution<long long>(l, r)(rng);
}

vector<long long> rand_array(int n, long long l, long long r) {
    vector<long long> a(n);
    for (auto &x : a) x = rand_int(l, r);
    return a;
}

vector<int> rand_permutation(int n) {
    vector<int> p(n);
    iota(p.begin(), p.end(), 1);
    shuffle(p.begin(), p.end(), rng);
    return p;
}

string rand_string(int n, string charset = "abcdefghijklmnopqrstuvwxyz") {
    string s = "";
    for (int i = 0; i < n; ++i) s += charset[rand_int(0, (int)charset.size() - 1)];
    return s;
}

// Generate random connected tree of n vertices (1-indexed)
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

// Write your testcase generation logic here:
int main() {
    int t = 1;
    cout << t << "\n";
    int n = rand_int(1, 10);
    cout << n << "\n";
    auto a = rand_array(n, 1, 100);
    for (int i = 0; i < n; ++i) {
        cout << a[i] << (i + 1 == n ? "" : " ");
    }
    cout << "\n";
}
]])
      f:close()
      created_any = true
    end
  end

  return created_any
end

function M.open_brute()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Open a C++ file first!", vim.log.levels.WARN)
    return
  end
  local dir = vim.fn.fnamemodify(file, ":h")
  M.ensure_files(dir)
  vim.cmd("vsplit " .. dir .. "/brute.cpp")
end

function M.open_gen()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Open a C++ file first!", vim.log.levels.WARN)
    return
  end
  local dir = vim.fn.fnamemodify(file, ":h")
  M.ensure_files(dir)
  vim.cmd("vsplit " .. dir .. "/gen.cpp")
end

function M.run()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Open a C++ file to run stress testing!", vim.log.levels.WARN, { title = "Stress Test" })
    return
  end

  local dir = vim.fn.fnamemodify(file, ":h")
  local sol_name = vim.fn.fnamemodify(file, ":t")

  local created_any = M.ensure_files(dir)
  if created_any then
    vim.notify("Created brute.cpp (with full CP template) and gen.cpp (with generator helpers)!\nUse <leader>rB and <leader>rG to view/edit them.", vim.log.levels.INFO, { title = "Stress Test" })
    return
  end

  -- Auto-save current file before testing
  vim.cmd("silent! write")

  local stress_cmd = string.format([[
cd '%s' && bash -c '
echo -e "\033[1;34m=== COMPILING %s, brute.cpp, and gen.cpp ===\033[0m"
g++ -O2 -std=c++23 "%s" -o __sol || exit 1
g++ -O2 -std=c++23 brute.cpp -o __brute || exit 1
g++ -O2 -std=c++23 gen.cpp -o __gen || exit 1

echo -e "\033[1;32m=== STRESS TESTING RUNNING (Press Ctrl+C to stop) ===\033[0m"
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
]], dir, sol_name, sol_name)

  if Snacks and Snacks.terminal then
    Snacks.terminal.open(stress_cmd, { cwd = dir })
  else
    vim.cmd("botright 15split | terminal " .. stress_cmd)
  end
end

return M
