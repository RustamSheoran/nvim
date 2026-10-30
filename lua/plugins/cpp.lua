local function find_clang_format()
  for _, path in ipairs({
    "/usr/bin/clang-format",
    "/opt/homebrew/bin/clang-format",
    "/usr/local/bin/clang-format",
  }) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  return "clang-format"
end

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

      opts.keymap = opts.keymap or {}
      -- Keep Tab as standard 2-space indentation / snippet navigation; remove Copilot accept from Tab
      opts.keymap["<Tab>"] = { "snippet_forward", "fallback" }
      opts.keymap["<S-Tab>"] = { "snippet_backward", "fallback" }
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

  -- 4. Google C++ code formatting: Keep empty functions open
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        cpp = { "clang-format" },
        c = { "clang-format" },
      },
      formatters = {
        ["clang-format"] = {
          command = find_clang_format(),
          condition = function(self, ctx)
            -- 1. Never format leetcode_template.cpp directly
            local filename = vim.fn.fnamemodify(ctx.filename, ":t")
            if filename == "leetcode_template.cpp" then
              return false
            end

            -- 2. If the buffer is just the lcc template (no user code written yet), don't format it
            local lines = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
            local has_lcc = false
            local has_code_after_lcc = false
            local found_fast_io = false
            for _, l in ipairs(lines) do
              if found_fast_io then
                local trimmed = vim.trim(l)
                if trimmed ~= "" and not trimmed:match("^//%s*clang%-format%s+on") then
                  has_code_after_lcc = true
                  break
                end
              elseif l:find("static const auto fast_io", 1, true) then
                has_lcc = true
                found_fast_io = true
              end
            end

            if has_lcc and not has_code_after_lcc then
              return false
            end

            return true
          end,
          prepend_args = {
            "--style={BasedOnStyle: Google, AllowShortFunctionsOnASingleLine: InlineOnly, KeepEmptyLines: {AtStartOfBlock: true}}",
          },
        },
      },
    },
  },

  -- 5. GitHub Copilot: Native inline ghost suggestions (turned off by default, toggled via <leader>tc)
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = false,
        hide_during_completion = false,
        debounce = 75,
        keymap = {
          accept = "<M-l>",
          accept_word = "<M-w>",
          accept_line = "<M-j>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = false,
        help = false,
        ["*"] = false,
      },
    },
    config = function(_, opts)
      require("copilot").setup(opts)
      vim.cmd("Copilot disable")
    end,
  },
}
