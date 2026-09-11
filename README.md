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

### 1. File Creation & Auto-Jump Magic
Whether you create a file manually or fetch one from the browser, the setup does the heavy lifting for you:
- If you create **any** file inside the `~/cp/` directory, Neovim automatically populates it with your `cp_template.cpp`.
- **Auto-Jump:** As soon as the file is created or opened, Neovim searches for the `void solve() {` block, automatically jumps your cursor inside it, and puts you into Insert Mode. You can just start typing your logic immediately!

### 2. LeetCode Integration
If you are doing LeetCode manually outside the `~/cp/` folder, we've got you covered:
- Open any `.cpp` file and type `lcc`.
- Your autocompletion will expand it into a fully minified, 1-line LeetCode helper template (containing all your fast I/O, macros, and math functions without cluttering the screen). You can immediately paste the `class Solution` right beneath it!

### 3. Fetching a Problem
- Open a terminal in your `~/cp/` directory and launch Neovim.
- Open a Codeforces problem in your browser and click the **green plus icon** (Competitive Companion).
- **What happens:** Neovim instantly catches the problem data on port `27121`. It builds the folder structure, creates the `.cpp` file (applying the template and jumping your cursor), and saves all the test cases. 

### 4. Formatting (clang-format)
We use `clang-format` as the absolute gold standard for C++ formatting.
- **On by Default:** Auto-formatting is globally enabled. Every time you save your file (`Ctrl + S`), Neovim automatically runs `clang-format` on your code.
- **Manual Formatting:** If you want to format your code without saving, just press `<leader>cf` (Space + c + f) to format the current buffer.

### 5. Testing Your Code
This setup uses `competitest.nvim` under the hood to manage test cases natively.
- Press `<leader>rr` to run your code against the sample test cases.
- **Custom Inputs:** If you want to test edge cases, you don't have to use the terminal. Press `<leader>ra` to add a new test case, or `<leader>re` to edit existing ones in a clean UI popup. 

### 6. Submitting 
- When your code is ready, press `<leader>rs`.
- Neovim runs a lightning-fast background syntax check (`g++ -fsyntax-only`). If you have a typo or missing semicolon, it aborts the submission and warns you—saving you from a penalty.
- If it compiles cleanly, Neovim sends your code (formatted as C++23) straight to the `cph-submit` browser extension, which submits it to Codeforces automatically.

## Default Template

Here is the default CP template that gets automatically injected into every new C++ file. (Click to expand)

<details>
<summary>View cp_template.cpp</summary>

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
