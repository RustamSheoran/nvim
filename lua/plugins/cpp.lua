return {
  -- 1. Fast completion: prioritize exact matches & CP macros, disable popup inside comments
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.fuzzy = opts.fuzzy or {}
      opts.fuzzy.sorts = {
        -- 1. Exact matches ALWAYS come first (no hardcoding needed):
        -- e.g. typing "pb" -> exact "pb" beats "pop_back"; typing "ll" -> exact "ll" beats fuzzy matches
        "exact",

        -- 2. Natural fuzzy match score
        "score",

        -- 3. Concise label length breaks score ties:
        -- Short identifiers and macros naturally rank above long multi-word symbols
        function(a, b)
          if #a.label ~= #b.label then
            return #a.label < #b.label
          end
        end,

        -- 4. Lexicographical tie-breaker
        "sort_text",
      }

      opts.sources = opts.sources or {}
      opts.sources.default = function()
        local success, node = pcall(vim.treesitter.get_node)
        if
          success
          and node
          and vim.tbl_contains({ "comment", "line_comment", "block_comment", "comment_content" }, node:type())
        then
          return {}
        end
        return { "snippets", "lsp", "buffer", "path" }
      end
    end,
  },

  -- 2. Fast Clangd LSP: no clang-tidy lag, no unwanted headers, no inlay hint lag
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = false,
      },
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy=false",
            "--header-insertion=never",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "-j=4",
          },
        },
      },
    },
  },

  -- 3. Ensure clangd_extensions doesn't show inline virtual hints
  {
    "p00f/clangd_extensions.nvim",
    opts = {
      inlay_hints = {
        inline = false,
      },
    },
  },

  -- 4. Google C++ code formatting
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        cpp = { "clang-format" },
        c = { "clang-format" },
      },
      formatters = {
        ["clang-format"] = {
          prepend_args = { "--style=Google" },
        },
      },
    },
  },
}
