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

// 0-indexing shortcuts
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
