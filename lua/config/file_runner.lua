-- ==============================================================================
-- Meta Hacker Cup / USACO Input File Picker & Runner (<leader>rm / <leader>rf)
-- ==============================================================================
-- Opens ~/Downloads directly in Snacks file picker. Selecting any downloaded
-- input file compiles your C++ solution, runs with redirection (./bin < in > out),
-- automatically creates output.txt in your problem directory, copies the path
-- to system clipboard for instant web upload, and opens output.txt in a split.
local M = {}

function M.execute_with_file(source_file, input_file)
  local dir = vim.fn.fnamemodify(source_file, ":h")
  local output_file = dir .. "/output.txt"
  local bin_file = "/tmp/__file_runner_bin"

  local src_name = vim.fn.fnamemodify(source_file, ":t")
  local in_name = vim.fn.fnamemodify(input_file, ":t")

  vim.notify(string.format("⚡ Compiling %s and running with input: %s...", src_name, in_name), vim.log.levels.INFO, { title = "Meta Runner" })

  local comp_cmd = {
    "g++", "-O2", "-std=c++17", "-fuse-ld=mold",
    source_file, "-o", bin_file,
  }

  vim.system(comp_cmd, { text = true }, function(comp_obj)
    if comp_obj.code ~= 0 then
      vim.schedule(function()
        vim.notify("=== COMPILATION FAILED ===\n" .. (comp_obj.stderr or ""), vim.log.levels.ERROR, { title = "Compile Error" })
      end)
      return
    end

    local exec_script = string.format([[
      bash -c '
        ulimit -s 262144 2>/dev/null
        _start=$(date +%%s%%N)
        "%s" < "%s" > "%s"
        _rc=$?
        _end=$(date +%%s%%N)
        _elapsed=$(( (_end - _start) / 1000000 ))
        echo "ELAPSED:$_elapsed"
        exit $_rc
      '
    ]], bin_file, input_file, output_file)

    vim.system({ "bash", "-c", exec_script }, { text = true }, function(exec_obj)
      pcall(vim.fn.delete, bin_file)

      vim.schedule(function()
        if exec_obj.code ~= 0 then
          local err = exec_obj.stderr or ""
          vim.notify("=== RUNTIME ERROR ===\n" .. err, vim.log.levels.ERROR, { title = "Runtime Error" })
          return
        end

        local elapsed = (exec_obj.stdout or ""):match("ELAPSED:(%d+)") or "0"
        local line_count = 0
        local f = io.open(output_file, "r")
        if f then
          for _ in f:lines() do
            line_count = line_count + 1
          end
          f:close()
        end

        -- Copy output file path to clipboard for instant upload dialogs
        pcall(vim.fn.setreg, "+", output_file)
        pcall(vim.fn.setreg, '"', output_file)

        local msg = string.format("✅ Execution finished in %s ms!\n📄 Output: %s (%d lines)\n📋 Path copied to clipboard for upload!", elapsed, output_file, line_count)
        vim.notify(msg, vim.log.levels.INFO, { title = "Meta Runner" })

        -- Open output.txt in a vertical split for immediate visual check
        local cur_win = vim.api.nvim_get_current_win()
        vim.cmd("vertical split " .. vim.fn.fnameescape(output_file))
        pcall(vim.api.nvim_set_current_win, cur_win)
      end)
    end)
  end)
end

function M.run()
  local file = vim.fn.expand("%:p")
  if file == "" or vim.bo.filetype ~= "cpp" then
    vim.notify("Please open a C++ file first!", vim.log.levels.WARN, { title = "Meta Runner" })
    return
  end

  vim.cmd("silent! write")
  local downloads_dir = vim.fn.expand("~/Downloads")

  if Snacks and Snacks.picker then
    Snacks.picker.files({
      cwd = downloads_dir,
      title = "Meta Hacker Cup Input (~/Downloads -> <Enter> to Run)",
      actions = {
        confirm = function(picker, item)
          picker:close()
          if item then
            local selected = item.file or item.path or (item[1] and item[1].file)
            if selected and not selected:match("^/") then
              selected = vim.fs.normalize(downloads_dir .. "/" .. selected)
            end
            if selected and vim.fn.filereadable(selected) == 1 then
              vim.schedule(function()
                M.execute_with_file(file, selected)
              end)
            end
          end
        end,
      },
    })
    return
  end

  -- Fallback if Snacks is not loaded
  vim.ui.input({ prompt = "Select Input File: ", default = downloads_dir .. "/" }, function(input)
    if input and input ~= "" and vim.fn.filereadable(input) == 1 then
      M.execute_with_file(file, input)
    end
  end)
end

return M
