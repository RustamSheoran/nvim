#!/usr/bin/env bash
set -e

# ==============================================================================
# Ultra-Fast Competitive Programming IDE Setup Script
# Supported automated platforms: Linux package managers and macOS/Homebrew
# ==============================================================================

echo "========================================================"
echo " Starting Competitive Programming Neovim IDE Setup"
echo "========================================================"

# 1. Determine directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONFIG="$HOME/.config/nvim"

if [ "$SCRIPT_DIR" != "$TARGET_CONFIG" ]; then
    if [ -e "$TARGET_CONFIG" ]; then
        BACKUP_PATH="$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)"
        echo "[*] Existing Neovim config detected at $TARGET_CONFIG"
        echo "[*] Moving existing config to $BACKUP_PATH..."
        mv "$TARGET_CONFIG" "$BACKUP_PATH"
    fi
    mkdir -p "$HOME/.config"
    echo "[*] Moving repository to $TARGET_CONFIG..."
    cp -r "$SCRIPT_DIR" "$TARGET_CONFIG"
    rm -rf "$SCRIPT_DIR"
    cd "$TARGET_CONFIG"
    echo "[*] Working directory is now $TARGET_CONFIG"
else
    echo "[*] Repository is already located at $TARGET_CONFIG"
fi

# 2. Detect Operating System
OS="$(uname -s)"

if [ "$OS" = "Linux" ]; then
    # Verify the Linux environment. Package names are selected per manager.
    if [ ! -d "/proc" ]; then
        echo "[!] Error: /proc not found. Unsupported Linux environment."
        exit 1
    fi

    if command -v pacman >/dev/null 2>&1; then
        echo "[*] Detected Arch Linux environment."
        sudo pacman -S --noconfirm --needed neovim gcc clang mold nodejs python sqlite curl ripgrep fd ttf-jetbrains-mono-nerd
    elif command -v apt-get >/dev/null 2>&1; then
        echo "[*] Detected Debian/Ubuntu-style Linux environment."
        sudo apt-get install -y neovim g++ clang mold nodejs python3 sqlite3 curl ripgrep fd-find
    elif command -v dnf >/dev/null 2>&1; then
        echo "[*] Detected Fedora/RHEL-style Linux environment."
        sudo dnf install -y neovim gcc-c++ clang mold nodejs python3 sqlite curl ripgrep fd-find
    else
        echo "[!] No supported Linux package manager found; skipping package installation."
        echo "    Install Neovim, a C++ compiler, curl, Python 3, SQLite, ripgrep, and fd manually."
    fi

    # 3. Stack limit increase for Linux (256 MB = 262144 KB)
    echo "[*] Configuring 256 MB stack limit for Arch Linux..."
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ ! -f "$rc" ]; then
            touch "$rc"
        fi
        if ! grep -q "ulimit -s 262144" "$rc"; then
            echo "ulimit -s 262144 2>/dev/null" >> "$rc"
            echo "    Added ulimit -s 262144 to $rc"
        fi
    done
    if [ -d "$HOME/.config/fish" ]; then
        FISH_CONF="$HOME/.config/fish/config.fish"
        if [ ! -f "$FISH_CONF" ]; then
            touch "$FISH_CONF"
        fi
        if ! grep -q "ulimit -s 262144" "$FISH_CONF"; then
            echo "ulimit -s 262144 2>/dev/null" >> "$FISH_CONF"
            echo "    Added ulimit -s 262144 to $FISH_CONF"
        fi
    fi
    if [ -d "/etc/security/limits.d" ]; then
        echo "[*] Setting system-wide stack limit in /etc/security/limits.d/99-cp-stack.conf..."
        echo -e "* soft stack 262144\n* hard stack 262144" | sudo tee /etc/security/limits.d/99-cp-stack.conf >/dev/null || true
    fi
    ulimit -s 262144 2>/dev/null || true

    # 4. Precompile bits/stdc++.h for C++17, C++20, and C++23 on Arch Linux
    echo "[*] Locating bits/stdc++.h for GCC..."
    BITS_HEADER=$(find /usr/include/c++ -path "*/bits/stdc++.h" ! -path "*/32/*" 2>/dev/null | head -n 1)

    if [ -n "$BITS_HEADER" ] && [ -f "$BITS_HEADER" ]; then
        GCH_DIR="$(dirname "$BITS_HEADER")/stdc++.h.gch"
        echo "[*] Found bits/stdc++.h at: $BITS_HEADER"
        echo "[*] Creating PCH directory: $GCH_DIR..."
        sudo mkdir -p "$GCH_DIR"

        for std in c++17 c++20 c++23; do
            echo "[*] Precompiling for $std (-O2)..."
            sudo g++ -O2 -std=$std -x c++-header "$BITS_HEADER" -o "$GCH_DIR/${std}_O2.gch"
            echo "[*] Precompiling for $std (debug)..."
            sudo g++ -std=$std -x c++-header "$BITS_HEADER" -o "$GCH_DIR/${std}.gch"
        done

        echo "[*] GCC Precompiled Headers for C++17, C++20, and C++23 successfully created!"
    else
        echo "[!] Warning: bits/stdc++.h not found under /usr/include/c++."
    fi

elif [ "$OS" = "Darwin" ]; then
    echo "[*] Detected macOS environment."

    if ! command -v brew >/dev/null 2>&1; then
        echo "[*] Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    echo "[*] Installing required packages via Homebrew (neovim, gcc, llvm, mold, node, python, clang-format, sqlite, curl, ripgrep, fd)..."
    brew install neovim gcc llvm mold node python clang-format sqlite curl ripgrep fd
    echo "[*] Installing JetBrains Mono Nerd Font via Homebrew..."
    brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null || true

    # 3. Stack limit increase for macOS (Darwin max shell limit: 65520 KB)
    echo "[*] Configuring stack limit for macOS..."
    for rc in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ ! -f "$rc" ]; then
            touch "$rc"
        fi
        if ! grep -q "ulimit -s 65520" "$rc"; then
            echo "ulimit -s 65520 2>/dev/null" >> "$rc"
            echo "    Added ulimit -s 65520 to $rc"
        fi
    done
    ulimit -s 65520 2>/dev/null || true

    # 4. Setup and precompile bits/stdc++.h for macOS
    echo "[*] Configuring bits/stdc++.h for macOS..."
    for base_inc in "/opt/homebrew/include" "/usr/local/include"; do
        if [ -d "$base_inc" ] || [ -d "$(dirname "$base_inc")" ]; then
            MACOS_BITS_DIR="$base_inc/bits"
            if [ -w "$(dirname "$MACOS_BITS_DIR")" ]; then
                mkdir -p "$MACOS_BITS_DIR"
            else
                sudo mkdir -p "$MACOS_BITS_DIR" 2>/dev/null || true
            fi

            TARGET_HEADER="$MACOS_BITS_DIR/stdc++.h"
            if [ ! -f "$TARGET_HEADER" ]; then
                echo "[*] Downloading official GNU bits/stdc++.h into $TARGET_HEADER..."
                CURL_URL="https://raw.githubusercontent.com/gcc-mirror/gcc/master/libstdc%2B%2B-v3/include/precompiled/stdc%2B%2B.h"
                if [ -w "$MACOS_BITS_DIR" ]; then
                    curl -fsSL "$CURL_URL" -o "$TARGET_HEADER" || true
                else
                    sudo curl -fsSL "$CURL_URL" -o "$TARGET_HEADER" 2>/dev/null || true
                fi
                echo "[*] bits/stdc++.h installed at $TARGET_HEADER!"
            else
                echo "[*] bits/stdc++.h already present at $TARGET_HEADER"
            fi

            # Precompile PCH for Homebrew GCC if installed on macOS
            GXX_BIN=""
            for cmd in g++-15 g++-14 g++-13 g++; do
                if command -v "$cmd" >/dev/null 2>&1; then
                    GXX_BIN="$cmd"
                    break
                fi
            done
            if [ -n "$GXX_BIN" ] && [ -f "$TARGET_HEADER" ]; then
                MACOS_GCH_DIR="$MACOS_BITS_DIR/stdc++.h.gch"
                echo "[*] Creating macOS PCH directory: $MACOS_GCH_DIR..."
                if [ -w "$MACOS_BITS_DIR" ]; then
                    mkdir -p "$MACOS_GCH_DIR"
                else
                    sudo mkdir -p "$MACOS_GCH_DIR" 2>/dev/null || true
                fi
                for std in c++17 c++20 c++23; do
                    echo "[*] Precompiling for $std (-O2) with $GXX_BIN..."
                    if [ -w "$MACOS_GCH_DIR" ]; then
                        $GXX_BIN -O2 -std=$std -x c++-header "$TARGET_HEADER" -o "$MACOS_GCH_DIR/${std}_O2.gch" 2>/dev/null || true
                        $GXX_BIN -std=$std -x c++-header "$TARGET_HEADER" -o "$MACOS_GCH_DIR/${std}.gch" 2>/dev/null || true
                    else
                        sudo $GXX_BIN -O2 -std=$std -x c++-header "$TARGET_HEADER" -o "$MACOS_GCH_DIR/${std}_O2.gch" 2>/dev/null || true
                        sudo $GXX_BIN -std=$std -x c++-header "$TARGET_HEADER" -o "$MACOS_GCH_DIR/${std}.gch" 2>/dev/null || true
                    fi
                done
                echo "[*] macOS GCC Precompiled Headers for C++17, C++20, and C++23 successfully created!"
            fi
        fi
    done

    # Ensure g++ command is available and links to Homebrew GCC on macOS
    GXX_BIN=""
    for cmd in g++-15 g++-14 g++-13 g++; do
        if command -v "$cmd" >/dev/null 2>&1; then
            GXX_BIN="$cmd"
            break
        fi
    done
    if [ -n "$GXX_BIN" ] && [ "$GXX_BIN" != "g++" ]; then
        if [ -d "/opt/homebrew/bin" ] && [ -w "/opt/homebrew/bin" ]; then
            ln -sf "$(which $GXX_BIN)" "/opt/homebrew/bin/g++" 2>/dev/null || true
        elif [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
            ln -sf "$(which $GXX_BIN)" "/usr/local/bin/g++" 2>/dev/null || true
        else
            sudo ln -sf "$(which $GXX_BIN)" "/usr/local/bin/g++" 2>/dev/null || true
        fi
    fi

else
    echo "[!] Unsupported operating system: $OS"
    echo "    The config files are portable, but setup.sh only automates Linux and macOS."
    exit 1
fi

# 5. Shell alias for Competitive Programming (cf -> cd ~/cp && nvim)
echo "[*] Ensuring ~/cp directory exists..."
mkdir -p "$HOME/cp"

echo "[*] Configuring 'cf' alias for all shells..."
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$rc" ]; then
        if ! grep -q "alias cf=" "$rc"; then
            echo "alias cf='cd ~/cp && nvim'" >> "$rc"
            echo "    Added alias cf to $rc"
        fi
    fi
done

if [ -d "$HOME/.config/fish" ]; then
    FISH_CONF="$HOME/.config/fish/config.fish"
    if [ -f "$FISH_CONF" ]; then
        if ! grep -q "alias cf=" "$FISH_CONF"; then
            echo "alias cf='cd ~/cp && nvim'" >> "$FISH_CONF"
            echo "    Added alias cf to $FISH_CONF"
        fi
    fi
fi

# 6. Default C++ formatting configuration (~/.clang-format)
if [ ! -f "$HOME/.clang-format" ]; then
    echo "[*] Creating default ~/.clang-format (Google style, 2-space indent)..."
    cat << 'EOF' > "$HOME/.clang-format"
BasedOnStyle: Google
IndentWidth: 2
ColumnLimit: 100
EOF
fi

echo ""
echo "========================================================"
echo " Installation Complete!"
echo " Open Neovim by typing: nvim"
echo " LazyVim will automatically install all plugins on first launch."
echo "========================================================"
