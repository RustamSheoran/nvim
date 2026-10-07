local M = {}

function M.run()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Open a C++ file to run in debug mode!", vim.log.levels.WARN, { title = "Debug Runner" })
    return
  end

  -- Auto-save current file
  vim.cmd("silent! write")

  local dir = vim.fn.fnamemodify(file, ":h")
  local sol_name = vim.fn.fnamemodify(file, ":t")
  local tc_file = vim.fn.fnamemodify(file, ":r") .. ".testcases"

  -- Collect testcases if available
  local tc_list = {}
  if vim.fn.filereadable(tc_file) == 1 then
    pcall(function()
      local tctbl = require("competitest.testcases").single_file.load(tc_file)
      local keys = {}
      for k in pairs(tctbl) do
        table.insert(keys, k)
      end
      table.sort(keys)
      for _, k in ipairs(keys) do
        if tctbl[k] and tctbl[k].input and tctbl[k].input ~= "" then
          table.insert(tc_list, {
            input = tctbl[k].input,
            output = tctbl[k].output,
          })
        end
      end
    end)
  end

  -- Write individual testcase files
  local run_cases_bash = ""
  if #tc_list > 0 then
    local commands = {}
    for i, tc in ipairs(tc_list) do
      local in_name = string.format("__tc_in_%d.txt", i)
      local f = io.open(dir .. "/" .. in_name, "w")
      if f then
        f:write(tc.input)
        f:close()
      end

      local exp_str = ""
      if tc.output and tc.output ~= "" then
        local exp_name = string.format("__tc_exp_%d.txt", i)
        local ef = io.open(dir .. "/" .. exp_name, "w")
        if ef then
          ef:write(tc.output)
          ef:close()
        end
        exp_str = string.format([[
echo -e "\033[1;35m--- EXPECTED OUTPUT ---\033[0m"
cat '%s'
echo ""
]], exp_name)
      end

      table.insert(commands, string.format([[
echo -e "\033[1;36m=================================================="
echo -e "📋 SAMPLE TESTCASE #%d"
echo -e "==================================================\033[0m"
echo -e "\033[1;33m--- INPUT ---\033[0m"
cat '%s'
echo ""
%s
echo -e "\033[1;32m--- YOUR OUTPUT & DEBUG (with -DLOCAL -DDEBUG) ---\033[0m"
./__debug < '%s'
echo ""
]], i, in_name, exp_str, in_name))
    end

    run_cases_bash = table.concat(commands, "\n")
  end

  local debug_cmd = ""
  if #tc_list > 0 then
    debug_cmd = string.format([[
cd '%s' && bash -c '
echo -e "\033[1;34m=== COMPILING %s (with -DLOCAL -DDEBUG) ===\033[0m"
g++ -O2 -std=c++23 -DLOCAL -DDEBUG "%s" -o __debug || { echo -e "\033[1;31mCompilation failed!\033[0m"; read -p "Press Enter to exit..." dummy; exit 1; }

%s
echo -e "\033[1;34m==================================================\033[0m"
echo -e "\033[1;32mAll %d testcases finished.\033[0m"
read -p "Press 'i' to run interactively, or Enter to close: " choice
if [ "$choice" = "i" ] || [ "$choice" = "I" ]; then
    echo -e "\033[1;32m=== INTERACTIVE RUN (./__debug) ===\033[0m"
    echo -e "\033[0;36mType / paste input and press Enter (Ctrl+D for EOF, Ctrl+C to stop):\033[0m"
    ./__debug
    echo ""
    read -p "Process exited. Press Enter to close window..." dummy
fi
'
]], dir, sol_name, sol_name, run_cases_bash, #tc_list)
  else
    debug_cmd = string.format([[
cd '%s' && bash -c '
echo -e "\033[1;34m=== COMPILING %s (with -DLOCAL -DDEBUG) ===\033[0m"
g++ -O2 -std=c++23 -DLOCAL -DDEBUG "%s" -o __debug || { echo -e "\033[1;31mCompilation failed!\033[0m"; read -p "Press Enter to exit..." dummy; exit 1; }

echo -e "\033[1;32m=== INTERACTIVE RUN (./__debug) ===\033[0m"
echo -e "\033[0;36mType / paste input and press Enter (Ctrl+D for EOF, Ctrl+C to stop):\033[0m"
./__debug
echo ""
read -p "Process exited. Press Enter to close window..." dummy
'
]], dir, sol_name, sol_name)
  end

  if Snacks and Snacks.terminal then
    Snacks.terminal.open(debug_cmd, { cwd = dir })
  else
    vim.cmd("botright 15split | terminal " .. debug_cmd)
  end
end

return M
