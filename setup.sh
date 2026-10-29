#!/usr/bin/env bash
set -e

# ==============================================================================
# Ultra-Fast Competitive Programming IDE Setup Script
# Supported Platforms: Arch Linux and macOS ONLY
# ==============================================================================

echo "========================================================"
echo " Starting Competitive Programming Neovim IDE Setup"
echo "========================================================"

# 1. Determine directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONFIG="$HOME/.config/nvim"

if [ "$SCRIPT_DIR" != "$TARGET_CONFIG" ]; then
    if [ -e "$TARGET_CONFIG" ]; then
        BACKUP_PATH="$HOME/.config/nvim.bak"
        echo "[*] Existing Neovim config detected at $TARGET_CONFIG"
        echo "[*] Moving existing config to $BACKUP_PATH..."
        rm -rf "$BACKUP_PATH"
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
    # Verify Linux proc filesystem and Arch Linux pacman
    if [ ! -d "/proc" ]; then
        echo "[!] Error: /proc not found. Unsupported Linux environment."
        exit 1
    fi

    if ! command -v pacman >/dev/null 2>&1; then
        echo "[!] Error: pacman package manager not found."
        echo "    This setup script is configured for Arch Linux and macOS only."
        exit 1
    fi

    echo "[*] Detected Arch Linux environment."
    echo "[*] Installing required packages via pacman (neovim, gcc, clang, mold, nodejs)..."
    sudo pacman -S --noconfirm --needed neovim gcc clang mold nodejs

    # 3. Stack limit increase for Linux (256 MB = 262144 KB)
    echo "[*] Configuring 256 MB stack limit for Arch Linux..."
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            if ! grep -q "ulimit -s 262144" "$rc"; then
                echo "ulimit -s 262144" >> "$rc"
                echo "    Added ulimit -s 262144 to $rc"
            fi
        fi
    done
    ulimit -s 262144 2>/dev/null || true

    # 4. Precompile bits/stdc++.h on Arch Linux
    echo "[*] Locating bits/stdc++.h for GCC..."
    BITS_HEADER=$(find /usr/include/c++ -path "*/bits/stdc++.h" ! -path "*/32/*" 2>/dev/null | head -n 1)

    if [ -n "$BITS_HEADER" ] && [ -f "$BITS_HEADER" ]; then
        GCH_DIR="$(dirname "$BITS_HEADER")/stdc++.h.gch"
        echo "[*] Found bits/stdc++.h at: $BITS_HEADER"
        echo "[*] Creating PCH directory: $GCH_DIR..."
        sudo mkdir -p "$GCH_DIR"

        echo "[*] Precompiling for C++17 (-O2)..."
        sudo g++ -O2 -std=c++17 -x c++-header "$BITS_HEADER" -o "$GCH_DIR/c++17_O2.gch"

        echo "[*] Precompiling for C++17 (debug)..."
        sudo g++ -std=c++17 -x c++-header "$BITS_HEADER" -o "$GCH_DIR/c++17.gch"

        echo "[*] GCC Precompiled Headers successfully created!"
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

    echo "[*] Installing required packages via Homebrew (neovim, gcc, llvm, mold, node, clang-format)..."
    brew install neovim gcc llvm mold node clang-format

    # 3. Stack limit increase for macOS (Darwin max shell limit: 65520 KB)
    echo "[*] Configuring stack limit for macOS..."
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$rc" ]; then
            if ! grep -q "ulimit -s 65520" "$rc"; then
                echo "ulimit -s 65520" >> "$rc"
                echo "    Added ulimit -s 65520 to $rc"
            fi
        fi
    done
    ulimit -s 65520 2>/dev/null || true

    # 4. Setup bits/stdc++.h for macOS
    echo "[*] Configuring bits/stdc++.h for macOS..."
    MACOS_BITS_DIR="/usr/local/include/bits"
    if [ -d "/opt/homebrew/include" ]; then
        MACOS_BITS_DIR="/opt/homebrew/include/bits"
    fi

    if [ ! -f "$MACOS_BITS_DIR/stdc++.h" ]; then
        echo "[*] Installing bits/stdc++.h into $MACOS_BITS_DIR..."
        if [ -w "$(dirname "$MACOS_BITS_DIR")" ]; then
            mkdir -p "$MACOS_BITS_DIR"
            curl -sSL "https://raw.githubusercontent.com/gcc-mirror/gcc/master/libstdc%2B%2B-v3/include/precompiled/stdc%2B%2B.h" -o "$MACOS_BITS_DIR/stdc++.h"
        else
            sudo mkdir -p "$MACOS_BITS_DIR"
            sudo curl -sSL "https://raw.githubusercontent.com/gcc-mirror/gcc/master/libstdc%2B%2B-v3/include/precompiled/stdc%2B%2B.h" -o "$MACOS_BITS_DIR/stdc++.h"
        fi
        echo "[*] bits/stdc++.h installed successfully at $MACOS_BITS_DIR/stdc++.h!"
    else
        echo "[*] bits/stdc++.h already present at $MACOS_BITS_DIR/stdc++.h"
    fi

else
    echo "[!] Error: Unsupported operating system: $OS"
    echo "    This setup script only supports Arch Linux and macOS."
    exit 1
fi

echo ""
echo "========================================================"
echo " Installation Complete!"
echo " Open Neovim by typing: nvim"
echo " LazyVim will automatically install all plugins on first launch."
echo "========================================================"
