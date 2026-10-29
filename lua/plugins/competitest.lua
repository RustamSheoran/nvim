local function detect_judge_and_contest(task)
  local url = task.url or ""
  local group = task.group or "Misc"
  local judge = "Codeforces"

  if task.judge and task.judge ~= "" then
    judge = task.judge
  elseif url:find("atcoder%.jp") then
    judge = "AtCoder"
  elseif url:find("codechef%.com") then
    judge = "CodeChef"
  elseif url:find("cses%.fi") then
    judge = "CSES"
  elseif url:find("leetcode%.com") then
    judge = "LeetCode"
  elseif url:find("spoj%.com") then
    judge = "SPOJ"
  elseif url:find("kattis%.com") then
    judge = "Kattis"
  elseif url:find("hackerrank%.com") then
    judge = "HackerRank"
  elseif url:find("maang%.in") or url:find("algozenith") then
    judge = "AlgoZenith"
  elseif url:find("codeforces%.com") then
    judge = "Codeforces"
  else
    local prefix = group:match("^([%w_]+)%s*%-")
    if prefix and prefix ~= "" then
      judge = prefix
    end
  end

  local contest = group
  if contest:find("^" .. judge .. "%s*%-") then
    contest = contest:gsub("^" .. judge .. "%s*%-%s*", "")
  end
  contest = contest:gsub("[^%w_-]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  if contest == "" then
    contest = "Misc"
  end

  return judge, contest
end

local function get_problem_target_path(task, file_extension)
  file_extension = file_extension or "cpp"
  local url = task.url or ""
  local group = task.group or ""
  local name = task.name or "problem"

  -- Separate Meta Hacker Cup problems into dedicated directories
  -- (Prevents output.txt from being overwritten across different problems)
  local is_mhc = url:find("facebook%.com/codingcompetitions") ~= nil
    or url:find("hacker%-cup") ~= nil
    or url:find("metahackercup") ~= nil
    or group:lower():find("hacker%s*cup") ~= nil
    or group:lower():find("metahackercup") ~= nil

  if is_mhc then
    local year = url:match("hacker%-cup/(20%d%d)")
      or group:match("(20%d%d)")
      or os.date("%Y")

    local round = url:match("hacker%-cup/%d+/([^/]+)")
      or group:match("Round%s*([%w_]+)")
      or group:match("Practice%s*Round")
      or "round"
    round = round:lower():gsub("[^%w]", "")

    local letter = url:match("problems?/([%w_]+)")
      or name:match("^([A-Z]%d?)%s*[:%-]")
      or name:match("^([A-Z]%d?)%s+")
      or name:match("^([A-Z]%d?)$")
      or name:gsub("%s+", "_"):gsub("[^%w_-]", "")

    local prob_name = letter:match("^[A-Z]%d?$") and ("problem" .. letter) or letter
    return string.format("%s/cp/MetaHackerCup/%s/%s/%s/%s.%s",
      vim.fn.expand("~"), year, round, prob_name, prob_name, file_extension)
  end

  local judge, contest = detect_judge_and_contest(task)
  local clean_name = name:gsub("%s+", "_"):gsub("[^%w_-]", "")
  return string.format("%s/cp/%s/%s/%s.%s", vim.fn.expand("~"), judge, contest, clean_name, file_extension)
end

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
      local target_path = get_problem_target_path(task, file_extension)

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
      cpp = { exec = "g++", args = { "-O2", "-std=c++17", "-fuse-ld=mold", "$(FNAME)", "-o", "$(FNOEXT)" } },
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
      desc = "Open problem brute force (<stem>_brute.cpp)",
    },
    {
      "<leader>rG",
      function()
        require("config.stress").open_gen()
      end,
      desc = "Open problem generator (<stem>_gen.cpp)",
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
ulimit -s 262144 2>/dev/null
echo -e "\033[1;34m=== COMPILING WITH ADDRESS & UNDEFINED BEHAVIOR SANITIZERS ===\033[0m"
g++ -O2 -std=c++17 -fsanitize=address,undefined -g "%s" -o __san || { read -p "Compilation failed! Press Enter..." dummy; exit 1; }

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
      desc = "Verify compilation, comment dbg, and submit via cph-submit",
    },
    {
      "<leader>rl",
      function()
        require("config.codeforces").show_contest_list()
      end,
      desc = "Codeforces Contest Problems, Solve Counts & Live Rank",
    },
    {
      "<leader>rc",
      function()
        local filepath = vim.fn.expand("%:p")
        local count = require("config.cph_server").comment_dbg(filepath)
        vim.notify(string.format("Commented out %d dbg statement(s)", count), vim.log.levels.INFO, { title = "Debug" })
      end,
      desc = "Comment all dbg statements in buffer",
    },
    {
      "<leader>rC",
      function()
        local filepath = vim.fn.expand("%:p")
        local count = require("config.cph_server").uncomment_dbg(filepath)
        vim.notify(string.format("Uncommented %d dbg statement(s)", count), vim.log.levels.INFO, { title = "Debug" })
      end,
      desc = "Uncomment all dbg statements in buffer",
    },
    {
      "<leader>rk",
      function()
        require("config.cf_cookie_submit").toggle_cookie_allowed()
      end,
      desc = "Toggle Headless Cookie Submit (Global Privacy Consent)",
    },
    {
      "<leader>rh",
      function()
        require("config.cp_health").check()
      end,
      desc = "Pre-Contest Environment Health Check (GCC, Mold, PCH, Stack)",
    },
    {
      "<leader>rT",
      function()
        require("config.codeforces").show_contest_timer()
      end,
      desc = "Codeforces Contest Timer & Live Countdown HUD",
    },
    {
      "<leader>rm",
      function()
        require("config.file_runner").run()
      end,
      desc = "Meta Input: Pick file from ~/Downloads & run with redirection",
    },
    {
      "<leader>rf",
      function()
        require("config.file_runner").run()
      end,
      desc = "File Runner: Pick input file & run with redirection",
    },
  },
}
