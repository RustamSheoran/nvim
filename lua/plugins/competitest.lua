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
  lazy = false,
  opts = {
    companion_port = 27121,
    received_problems_prompt_path = false,
    received_contests_prompt_directory = false,
    received_contests_prompt_extension = false,

    -- Auto-save metadata to companion .meta.json when fetched via browser extension
    received_problems_path = function(task, file_extension)
      local target_path = get_problem_target_path(task, file_extension)

      local dir = vim.fn.fnamemodify(target_path, ":h")
      pcall(vim.fn.mkdir, dir, "p")

      local stem = vim.fn.fnamemodify(target_path, ":r")
      local meta_file = stem .. ".meta.json"
      local judge, contest = detect_judge_and_contest(task)
      local meta_data = {
        name = task.name or "problem",
        group = task.group or contest,
        url = task.url or "",
        judge = judge,
        timeLimit = task.timeLimit,
        memoryLimit = task.memoryLimit,
        tests = task.tests or {},
      }
      pcall(vim.fn.writefile, { vim.json.encode(meta_data) }, meta_file, "b")

      return target_path
    end,

    testcases_use_single_file = true,
    testcases_single_file_format = "$(FNOEXT).meta.json",
    template_file = {
      cpp = vim.fn.expand("~/.config/nvim/templates/cp_template.cpp"),
    },
    compile_command = {
      cpp = {
        exec = "g++",
        args = (function()
          local args = { "-O2", "-std=c++17", "-D_GLIBCXX_ASSERTIONS" }
          if vim.fn.executable("mold") == 1 and (vim.uv or vim.loop).os_uname().sysname == "Linux" then
            table.insert(args, "-fuse-ld=mold")
          end
          vim.list_extend(args, { "$(FNAME)", "-o", "$(FNOEXT)" })
          return args
        end)(),
      },
    },
    run_command = {
      cpp = { exec = "./$(FNOEXT)" },
    },
  },
  config = function(_, opts)
    local utils = require("competitest.utils")
    local tc = require("competitest.testcases")

    local orig_load = tc.single_file.load
    local orig_write = tc.single_file.write

    -- Unified testcases adapter: seamlessly read/write testcases directly from .meta.json
    tc.single_file.load = function(filepath)
      local meta_path = filepath:match("%.meta%.json$") and filepath or filepath:gsub("%.testcases$", ".meta.json")
      local path_to_read = vim.fn.filereadable(meta_path) == 1 and meta_path or filepath
      if vim.fn.filereadable(path_to_read) == 1 then
        local raw = utils.load_file_as_string(path_to_read)
        if raw and raw:match("^%s*{") then
          local ok, data = pcall(vim.json.decode, raw)
          if ok and type(data) == "table" and data.tests then
            local tctbl = {}
            for i, test in ipairs(data.tests) do
              tctbl[i - 1] = {
                input = test.input or "",
                output = test.output or "",
              }
            end
            return tctbl
          end
        end
      end
      return orig_load(filepath)
    end

    tc.single_file.write = function(filepath, tctbl)
      local meta_path = filepath:match("%.meta%.json$") and filepath or filepath:gsub("%.testcases$", ".meta.json")
      local target_file = (vim.fn.filereadable(meta_path) == 1 or filepath:match("%.meta%.json$")) and meta_path or filepath
      if target_file:match("%.meta%.json$") then
        local data = {}
        if vim.fn.filereadable(target_file) == 1 then
          local raw = utils.load_file_as_string(target_file)
          if raw then
            local ok, dec = pcall(vim.json.decode, raw)
            if ok and type(dec) == "table" then
              data = dec
            end
          end
        end

        local tests = {}
        local keys = {}
        for k, v in pairs(tctbl) do
          if (v.input and v.input ~= "") or (v.output and v.output ~= "") then
            table.insert(keys, k)
          end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
          local item = tctbl[k]
          table.insert(tests, {
            input = item.input or "",
            output = item.output or "",
          })
        end
        data.tests = tests

        local ok_enc, encoded = pcall(vim.json.encode, data)
        if ok_enc and encoded then
          pcall(vim.fn.writefile, { encoded }, target_file, "b")
          return
        end
      end
      orig_write(filepath, tctbl)
    end

    require("competitest").setup(opts)
    -- Start the CPH submit polling server
    require("config.cph_server").start()

    -- Keymap 's' inside CompetiTest runner UI to submit solution directly
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "CompetiTest",
      callback = function(ev)
        vim.keymap.set("n", "s", function()
          local ok_sub, runner = pcall(require, "competitest.runner")
          if ok_sub and runner and runner.current_runner then
            pcall(function() runner.current_runner:hide_ui() end)
          end
          vim.schedule(function()
            vim.cmd("normal! <leader>rs")
          end)
        end, { buffer = ev.buf, desc = "Submit solution directly from CompetiTest runner" })
      end,
    })
  end,
  keys = {
    { "<leader>rr", "<cmd>CompetiTest run<cr>", desc = "Run Testcases" },
    { "<leader>rp", "<cmd>Cp claim<cr>", desc = "Claim Problem Receiver Server" },
    { "<leader>ra", "<cmd>CompetiTest add_testcase<cr>", desc = "Add Testcase" },
    { "<leader>re", "<cmd>CompetiTest edit_testcase<cr>", desc = "Edit Testcase" },
    { "<leader>rd", "<cmd>CompetiTest delete_testcase<cr>", desc = "Delete Testcase" },
    {
      "<leader>rx",
      function()
        require("config.debug_runner").run()
      end,
      desc = "Run Local Debug (-DLOCAL -DDEBUG)",
    },
    {
      "<leader>rb",
      function()
        require("config.stress").run()
      end,
      desc = "Run Stress Test (sol vs brute)",
    },
    {
      "<leader>rw",
      function()
        require("config.stress").open_brute()
      end,
      desc = "Create/open brute-force template",
    },
    {
      "<leader>rg",
      function()
        require("config.stress").open_gen()
      end,
      desc = "Create/open random-test generator",
    },
    {
      "<leader>ru",
      function()
        local stem = vim.fn.expand("%:p:r")
        local meta_file = stem .. ".meta.json"
        local url = nil
        if vim.fn.filereadable(meta_file) == 1 then
          local lines = vim.fn.readfile(meta_file)
          local ok_dec, data = pcall(vim.json.decode, table.concat(lines, "\n"))
          if ok_dec and type(data) == "table" and data.url and data.url:match("^https?://") then
            url = data.url
          end
        end
        if not url then
          local url_file = stem .. ".url"
          if vim.fn.filereadable(url_file) == 1 then
            local lines = vim.fn.readfile(url_file)
            if #lines > 0 and lines[1]:match("^https?://") then
              url = vim.trim(lines[1])
            end
          end
        end
        if url then
          vim.ui.open(url)
          return
        end
        vim.notify("No problem URL found for this problem!", vim.log.levels.WARN)
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
        local stem = vim.fn.fnamemodify(file, ":r")
        local meta_file = stem .. ".meta.json"
        local tc_file = stem .. ".testcases"

        -- Collect testcases: check exact .meta.json, any .meta.json in dir, or .testcases
        local tc_list = {}
        local meta_candidates = { meta_file }
        for _, f in ipairs(vim.fn.glob(dir .. "/*.meta.json", false, true)) do
          if f ~= meta_file then
            table.insert(meta_candidates, f)
          end
        end

        for _, mf in ipairs(meta_candidates) do
          if #tc_list == 0 and vim.fn.filereadable(mf) == 1 then
            pcall(function()
              local lines = vim.fn.readfile(mf)
              local ok_dec, data = pcall(vim.json.decode, table.concat(lines, "\n"))
              if ok_dec and type(data) == "table" and data.tests then
                for _, t in ipairs(data.tests) do
                  if t.input and t.input ~= "" then
                    table.insert(tc_list, { input = t.input, output = t.output or "" })
                  end
                end
              end
            end)
          end
        end

        if #tc_list == 0 then
          local tc_candidates = { tc_file }
          for _, f in ipairs(vim.fn.glob(dir .. "/*.testcases", false, true)) do
            if f ~= tc_file then
              table.insert(tc_candidates, f)
            end
          end
          for _, tf in ipairs(tc_candidates) do
            if #tc_list == 0 and vim.fn.filereadable(tf) == 1 then
              pcall(function()
                local tctbl = require("competitest.testcases").single_file.load(tf)
                local keys = {}
                for k in pairs(tctbl) do table.insert(keys, k) end
                table.sort(keys)
                for _, k in ipairs(keys) do
                  if tctbl[k] and tctbl[k].input and tctbl[k].input ~= "" then
                    table.insert(tc_list, { input = tctbl[k].input, output = tctbl[k].output or "" })
                  end
                end
              end)
            end
          end
        end

        local mold_flag = (vim.fn.executable("mold") == 1 and (vim.uv or vim.loop).os_uname().sysname == "Linux") and "-fuse-ld=mold " or ""
        local san_cmd = ""

        if #tc_list > 0 then
          local commands = {}
          for i, tc in ipairs(tc_list) do
            local in_name = string.format("__tc_in_%d.txt", i)
            local f = io.open(dir .. "/" .. in_name, "w")
            if f then
              f:write(tc.input)
              f:close()
            end
            table.insert(commands, string.format([[
echo -e "\033[1;36m=================================================="
echo -e "📋 SAMPLE TESTCASE #%d (Address & UB Sanitizers)"
echo -e "==================================================\033[0m"
echo -e "\033[1;33m--- INPUT ---\033[0m"
cat '%s'
echo ""
echo -e "\033[1;32m--- OUTPUT & SANITIZER REPORT ---\033[0m"
./__san < '%s' || true
echo ""
]], i, in_name, in_name))
          end

          local run_cases_bash = table.concat(commands, "\n")
          san_cmd = string.format([[
cd '%s' && bash -c '
ulimit -s 262144 2>/dev/null || ulimit -s 65520 2>/dev/null || true
export ASAN_OPTIONS="handle_abort=1:detect_leaks=1:color=always"
export UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1:color=always"
echo -e "\033[1;34m=== COMPILING WITH ASAN & UBSAN ===\033[0m"
g++ -O2 -std=c++17 %s-fsanitize=address,undefined -fno-omit-frame-pointer -g "%s" -o __san || { echo -e "\033[1;31mCompilation failed!\033[0m"; read -p "Press Enter to exit..." dummy; exit 1; }

%s
echo -e "\033[1;34m==================================================\033[0m"
echo -e "\033[1;32mAll %d sample testcase(s) finished.\033[0m"
read -p "Press '\''i'\'' to test custom/interactive input, or Enter to close: " choice
if [ "$choice" = "i" ] || [ "$choice" = "I" ]; then
    echo -e "\033[1;32m=== INTERACTIVE RUN (./__san) ===\033[0m"
    echo -e "\033[0;36mType / paste input below, then press Enter and Ctrl+D (EOF):\033[0m"
    ./__san || true
    echo ""
    echo -e "\033[1;33m--------------------------------------------------\033[0m"
    read -p "Run complete. Press Enter to close window..." dummy
fi
'
]], dir, mold_flag, sol_name, run_cases_bash, #tc_list)
        else
          san_cmd = string.format([[
cd '%s' && bash -c '
ulimit -s 262144 2>/dev/null || ulimit -s 65520 2>/dev/null || true
export ASAN_OPTIONS="handle_abort=1:detect_leaks=1:color=always"
export UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1:color=always"
echo -e "\033[1;34m=== COMPILING WITH ASAN & UBSAN ===\033[0m"
g++ -O2 -std=c++17 %s-fsanitize=address,undefined -fno-omit-frame-pointer -g "%s" -o __san || { echo -e "\033[1;31mCompilation failed!\033[0m"; read -p "Press Enter to exit..." dummy; exit 1; }

echo -e "\033[1;32m=== INTERACTIVE RUN WITH SANITIZERS (Catches Out-of-Bounds & UB) ===\033[0m"
echo -e "\033[0;36mType / paste input below, then press Enter and Ctrl+D (EOF):\033[0m"
./__san || true
echo ""
echo -e "\033[1;33m--------------------------------------------------\033[0m"
read -p "Run complete. Press Enter to close window..." dummy
'
]], dir, mold_flag, sol_name)
        end

        if Snacks and Snacks.terminal then
          Snacks.terminal.open(san_cmd, {
            cwd = dir,
            auto_close = false,
            win = {
              on_buf = function(self)
                vim.keymap.set("n", "q", function() self:close() end, { buffer = self.buf, silent = true, desc = "Close terminal" })
              end,
            },
          })
        else
          vim.cmd("botright 15split | terminal " .. san_cmd)
        end
      end,
      desc = "Run with ASan & UBSan (catches out-of-bounds / segfaults)",
    },
    {
      "<leader>rs",
      function()
        -- Robust C++ target file discovery (works from CompetiTest UI, splits, or normal buffers)
        local function resolve_target_file()
          local cur = vim.api.nvim_buf_get_name(0)
          if cur:match("%.cpp$") and vim.fn.filereadable(cur) == 1 then
            return cur
          end
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
              local name = vim.api.nvim_buf_get_name(buf)
              if name:match("%.cpp$") and vim.fn.filereadable(name) == 1 and not name:match("_gen%.cpp$") and not name:match("_brute%.cpp$") then
                return name
              end
            end
          end
          return cur
        end

        local filepath = resolve_target_file()
        if not filepath or filepath == "" or vim.fn.filereadable(filepath) ~= 1 then
          vim.notify("Submit cancelled: no active C++ solution file found", vim.log.levels.WARN, { title = "Submit" })
          return
        end

        local bufnr = vim.fn.bufnr(filepath)
        if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
          pcall(vim.api.nvim_buf_call, bufnr, function()
            vim.cmd("silent! write")
          end)
        end

        local stem = vim.fn.fnamemodify(filepath, ":r")
        local meta_file = stem .. ".meta.json"
        local url_file = stem .. ".url"

        local function submit(url)
          if not url or url == "" then
            vim.notify("Submit cancelled: empty URL", vim.log.levels.WARN)
            return
          end
          require("config.cph_server").submit(url, filepath)
        end

        -- 1. Check companion .meta.json file
        if vim.fn.filereadable(meta_file) == 1 then
          local lines = vim.fn.readfile(meta_file)
          local ok_dec, data = pcall(vim.json.decode, table.concat(lines, "\n"))
          if ok_dec and type(data) == "table" and data.url and data.url:match("^https?://") then
            submit(vim.trim(data.url))
            return
          end
        end

        -- 2. Check legacy companion .url file
        if vim.fn.filereadable(url_file) == 1 then
          local lines = vim.fn.readfile(url_file)
          if #lines > 0 and lines[1]:match("^https?://") then
            submit(vim.trim(lines[1]))
            return
          end
        end

        -- 3. Check the first 15 lines of the source file
        local lines = vim.fn.readfile(filepath, "", 15)
        for _, line in ipairs(lines) do
          local match = line:match("(https?://[%w-_%.%?%.:/%+=&#]+)")
          if match then
            local mdata = { url = match }
            if vim.fn.filereadable(meta_file) == 1 then
              local ml = vim.fn.readfile(meta_file)
              local ok_dec, d = pcall(vim.json.decode, table.concat(ml, "\n"))
              if ok_dec and type(d) == "table" then
                mdata = d
                mdata.url = match
              end
            end
            pcall(vim.fn.writefile, { vim.json.encode(mdata) }, meta_file, "b")
            submit(match)
            return
          end
        end

        -- 4. Prompt if no URL was stored previously
        vim.ui.input({ prompt = "Enter Problem URL: " }, function(input)
          if input and input ~= "" then
            local clean_url = vim.trim(input)
            local mdata = { url = clean_url }
            if vim.fn.filereadable(meta_file) == 1 then
              local ml = vim.fn.readfile(meta_file)
              local ok_dec, d = pcall(vim.json.decode, table.concat(ml, "\n"))
              if ok_dec and type(d) == "table" then
                mdata = d
                mdata.url = clean_url
              end
            end
            pcall(vim.fn.writefile, { vim.json.encode(mdata) }, meta_file, "b")
            submit(clean_url)
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
        local count = require("config.cph_server").toggle_dbg(filepath)
        vim.notify(string.format("Toggled %d dbg statement(s)", count), vim.log.levels.INFO, { title = "Debug" })
      end,
      desc = "Toggle all dbg statements in buffer",
    },
    {
      "<leader>rk",
      function()
        require("config.cf_cookie_submit").toggle_cookie_allowed()
      end,
      desc = "Toggle Headless Cookie Submit (Global Privacy Consent)",
    },
    {
      "<leader>rn",
      function()
        require("config.cf_cookie_submit").fetch_new_cookies()
      end,
      desc = "Get / verify fresh Codeforces cookies (never cached)",
    },
    {
      "<leader>ro",
      function()
        require("config.cf_cookie_submit").fetch_new_cookies()
      end,
      desc = "Get / verify fresh Codeforces cookies (never cached)",
    },
    {
      "<leader>rh",
      function()
        require("config.cp_health").check()
      end,
      desc = "Pre-Contest Environment Health Check (GCC, Mold, PCH, Stack)",
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
