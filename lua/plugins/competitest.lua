return {
  "xeluxee/competitest.nvim",
  dependencies = "MunifTanjim/nui.nvim",
  lazy = not vim.fn.getcwd():find(vim.fn.expand("~/cp"), 1, true),
  opts = {
    received_problems_prompt_path = false,
    received_contests_prompt_directory = false,
    received_contests_prompt_extension = false,

    -- Auto-save URL to a companion .url file when fetched via browser extension
    received_problems_path = function(task, file_extension)
      local judge = task.judge or "Codeforces"
      local contest = (task.group or "Misc"):gsub("[^%w_-]", "_")
      local name = (task.name or "problem"):gsub("%s+", "_"):gsub("[^%w_-]", "")
      local target_path = string.format("%s/cp/%s/%s/%s.%s", vim.fn.expand("~"), judge, contest, name, file_extension)

      if task.url and task.url ~= "" then
        local dir = vim.fn.fnamemodify(target_path, ":h")
        vim.fn.mkdir(dir, "p")
        local url_file = vim.fn.fnamemodify(target_path, ":r") .. ".url"
        vim.fn.writefile({ task.url }, url_file, "b")
      end

      return target_path
    end,

    testcases_use_single_file = true,
    template_file = {
      cpp = vim.fn.expand("~/.config/nvim/templates/cp_template.cpp"),
    },
    compile_command = {
      cpp = { exec = "g++", args = { "-O2", "-std=c++23", "$(FNAME)", "-o", "$(FNOEXT)" } },
    },
    run_command = {
      cpp = { exec = "./$(FNOEXT)" },
    },
  },
  config = function(_, opts)
    require("competitest").setup(opts)
    -- Start the CPH submit polling server
    require("config.cph_server").start()
  end,
  keys = {
    { "<leader>rr", "<cmd>CompetiTest run<cr>", desc = "Run Testcases" },
    { "<leader>ra", "<cmd>CompetiTest add_testcase<cr>", desc = "Add Testcase" },
    { "<leader>re", "<cmd>CompetiTest edit_testcase<cr>", desc = "Edit Testcase" },
    { "<leader>rD", "<cmd>CompetiTest delete_testcase<cr>", desc = "Delete Testcase" },
    {
      "<leader>rd",
      function()
        require("config.debug_runner").run()
      end,
      desc = "Run Local Debug (-DLOCAL -DDEBUG)",
    },
    {
      "<leader>rx",
      function()
        require("config.debug_runner").run()
      end,
      desc = "Run Local Debug (alias)",
    },
    {
      "<leader>rb",
      function()
        require("config.stress").run()
      end,
      desc = "Run Stress Test (sol vs brute)",
    },
    {
      "<leader>rB",
      function()
        require("config.stress").open_brute()
      end,
      desc = "Open brute.cpp in vertical split",
    },
    {
      "<leader>rG",
      function()
        require("config.stress").open_gen()
      end,
      desc = "Open gen.cpp in vertical split",
    },
    {
      "<leader>ru",
      function()
        local url_file = vim.fn.expand("%:p:r") .. ".url"
        if vim.fn.filereadable(url_file) == 1 then
          local lines = vim.fn.readfile(url_file)
          if #lines > 0 and lines[1]:match("^https?://") then
            vim.ui.open(lines[1])
            return
          end
        end
        vim.notify("No .url file found for this problem!", vim.log.levels.WARN)
      end,
      desc = "Open problem URL in browser",
    },
    {
      "<leader>rz",
      function()
        local file = vim.fn.expand("%:p")
        if file == "" or vim.bo.filetype ~= "cpp" then
          vim.notify("Open a C++ file first!", vim.log.levels.WARN)
          return
        end
        vim.cmd("silent! write")
        local dir = vim.fn.fnamemodify(file, ":h")
        local sol_name = vim.fn.fnamemodify(file, ":t")
        local san_cmd = string.format([[
cd '%s' && bash -c '
echo -e "\033[1;34m=== COMPILING WITH ADDRESS & UNDEFINED BEHAVIOR SANITIZERS ===\033[0m"
g++ -O2 -std=c++23 -fsanitize=address,undefined -g "%s" -o __san || { read -p "Compilation failed! Press Enter..." dummy; exit 1; }

echo -e "\033[1;32m=== RUNNING WITH SANITIZERS (Catches Out-of-Bounds & UB) ===\033[0m"
if [ -f __debug_in.txt ]; then
    ./__san < __debug_in.txt
elif [ -f __tc_in_1.txt ]; then
    ./__san < __tc_in_1.txt
else
    echo -e "\033[0;36mType / paste input and press Enter:\033[0m"
    ./__san
fi
echo ""
read -p "Sanitizer run complete. Press Enter to close..." dummy
'
]], dir, sol_name)
        if Snacks and Snacks.terminal then
          Snacks.terminal.open(san_cmd, { cwd = dir })
        else
          vim.cmd("botright 15split | terminal " .. san_cmd)
        end
      end,
      desc = "Run with AddressSanitizer (catch segfaults / out-of-bounds)",
    },
    {
      "<leader>rs",
      function()
        local filepath = vim.fn.expand("%:p")
        local url_file = vim.fn.expand("%:p:r") .. ".url"

        local function submit(url)
          if not url or url == "" then
            vim.notify("Submit cancelled: empty URL", vim.log.levels.WARN)
            return
          end
          require("config.cph_server").submit(url, filepath)
        end

        -- 1. Check companion .url file
        if vim.fn.filereadable(url_file) == 1 then
          local lines = vim.fn.readfile(url_file)
          if #lines > 0 and lines[1]:match("^https?://") then
            submit(vim.trim(lines[1]))
            return
          end
        end

        -- 2. Check the first 10 lines of the buffer
        local lines = vim.api.nvim_buf_get_lines(0, 0, 10, false)
        for _, line in ipairs(lines) do
          local match = line:match("(https?://[%w-_%.%?%.:/%+=&#]+)")
          if match then
            vim.fn.writefile({ match }, url_file)
            submit(match)
            return
          end
        end

        -- 3. Prompt if no URL was stored previously
        vim.ui.input({ prompt = "Enter Problem URL: " }, function(input)
          if input and input ~= "" then
            vim.fn.writefile({ vim.trim(input) }, url_file)
            submit(vim.trim(input))
          end
        end)
      end,
      desc = "Verify compilation and submit via cph-submit",
    },
  },
}
