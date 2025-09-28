local M = {
  current_index = 0,
  stack = {},
  navigating = false,
}

M.config = {
  mappings = {
    add_pos = '<LEADER>;',
    jump_back = '<C-o>',
    jump_forward = '<C-i>',
  },
  persistence_file = vim.fn.expand('~/.config/vim-stack-positions.txt'),
  max_positions = 1000,
  setup_default_autocmd = true,
}

function M.add_pos()
  if M.current_index > 0 then
    -- Slicing the stack from current index to the end
    M.stack = vim.list_slice(M.stack, 1, M.current_index)
  end
  
  local pos = vim.api.nvim_win_get_cursor(0)
  local file_path = vim.api.nvim_buf_get_name(0)
  
  -- Check if this position already exists in the stack (ignoring column)
  for i = #M.stack, 1, -1 do
    local existing_entry = M.stack[i]
    if existing_entry.file_path == file_path and existing_entry.cursor_pos[1] == pos[1] then
      -- Remove the existing entry
      table.remove(M.stack, i)
      -- Adjust current_index if needed
      if i <= M.current_index then
        M.current_index = M.current_index - 1
      end
      break
    end
  end
  
  local entry = {
    file_path = file_path,
    cursor_pos = pos
  }
  table.insert(M.stack, entry)
  
  -- Keep only the last max_positions entries
  if #M.stack > M.config.max_positions then
    M.stack = vim.list_slice(M.stack, #M.stack - M.config.max_positions + 1, #M.stack)
  end
  
  M.current_index = #M.stack + 1
end

function M.jump_back()
  if #M.stack == 0 then
    print("Stack is empty")
    return
  end

  if M.current_index > 1 then
    M.current_index = M.current_index - 1
  else
    M.current_index = 1
  end
  
  M.navigating = true
  local entry = M.stack[M.current_index]
  local current_file = vim.api.nvim_buf_get_name(0)
  if entry.file_path and entry.file_path ~= "" and entry.file_path ~= current_file then
    vim.cmd("edit " .. entry.file_path)
  end
  vim.api.nvim_win_set_cursor(0, entry.cursor_pos)
  
  -- Reset navigation flag after a short delay
  vim.defer_fn(function()
    M.navigating = false
  end, 50)
end

function M.jump_forward()
  if #M.stack == 0 then
    print("Stack is empty")
    return
  end

  if M.current_index < #M.stack then
    M.current_index = M.current_index + 1
  else
    M.current_index = #M.stack
  end
  
  M.navigating = true
  local entry = M.stack[M.current_index]
  local current_file = vim.api.nvim_buf_get_name(0)
  if entry.file_path and entry.file_path ~= "" and entry.file_path ~= current_file then
    vim.cmd("edit " .. entry.file_path)
  end
  vim.api.nvim_win_set_cursor(0, entry.cursor_pos)
  
  -- Reset navigation flag after a short delay
  vim.defer_fn(function()
    M.navigating = false
  end, 50)
end

function M.save_to_file()
  local file = io.open(M.config.persistence_file, "w")
  if not file then
    return
  end
  
  for _, entry in ipairs(M.stack) do
    if entry.file_path and entry.file_path ~= "" then
      local line = string.format("%s:%d:%d\n", 
        entry.file_path, 
        entry.cursor_pos[1], 
        entry.cursor_pos[2])
      file:write(line)
    end
  end
  
  file:close()
end

function M.load_from_file()
  local file = io.open(M.config.persistence_file, "r")
  if not file then
    return
  end
  
  M.stack = {}
  M.current_index = 0
  
  for line in file:lines() do
    local file_path, row, col = line:match("^(.+):(%d+):(%d+)$")
    if file_path and row and col then
      local entry = {
        file_path = file_path,
        cursor_pos = {tonumber(row), tonumber(col)}
      }
      table.insert(M.stack, entry)
    end
  end
  
  M.current_index = #M.stack + 1
  file:close()
end

function M.clear()
  M.stack = {}
  M.current_index = 0
  print("Position stack cleared")
end

function M.show()
  if #M.stack == 0 then
    print("Position stack is empty")
    return
  end
  
  print("Position Stack (" .. #M.stack .. " entries):")
  print("Current index: " .. (M.current_index > #M.stack and "after last" or M.current_index))
  print(string.rep("-", 60))
  
  for i, entry in ipairs(M.stack) do
    local marker = ""
    if i == M.current_index then
      marker = " -> "
    else
      marker = "    "
    end
    
    local filename = entry.file_path
    if filename and filename ~= "" then
      -- Show only the filename, not the full path
      filename = vim.fn.fnamemodify(filename, ":t")
    else
      filename = "[No Name]"
    end
    
    print(string.format("%s%2d: %s:%d:%d", 
      marker, i, filename, entry.cursor_pos[1], entry.cursor_pos[2]))
  end
end

function M.add_default_autocmd()
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    group = "PosStack",
    callback = function()
      M.add_pos()
    end,
  })
  
  vim.api.nvim_create_autocmd("BufLeave", {
    group = "PosStack",
    callback = function()
      if not M.navigating then
        local bufnr = vim.api.nvim_get_current_buf()
        local file_path = vim.api.nvim_buf_get_name(bufnr)
        
        -- Check if buffer has a name and filepath
        if file_path == nil or file_path == "" then
          return
        end
        
        -- Check if buffer is visible (not hidden)
        if not vim.api.nvim_buf_is_loaded(bufnr) then
          return
        end
        
        -- Check if it's a real file (not a special buffer)
        local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
        if buftype ~= "" then
          return
        end
        
        M.add_pos()
      end
    end,
  })
end

function M.setup_mappings()
  local opts = { noremap = true, silent = true }

  vim.api.nvim_set_keymap("n",
    M.config.mappings.add_pos,
    "<Esc><Cmd>lua require('pos-stack').add_pos()<CR>",
    opts)

  vim.api.nvim_set_keymap("n",
    M.config.mappings.jump_back,
    "<Esc><Cmd>lua require('pos-stack').jump_back()<CR>",
    opts)

  vim.api.nvim_set_keymap("n",
    M.config.mappings.jump_forward,
    "<Esc><Cmd>lua require('pos-stack').jump_forward()<CR>",
    opts)
end

function M.setup(user_opts)
  M.config = vim.tbl_extend("force", M.config, user_opts or {})
  M.setup_mappings()
  
  -- Load positions on startup
  M.load_from_file()
  
  -- Set up autocommands for persistence
  vim.api.nvim_create_augroup("PosStack", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = "PosStack",
    callback = function()
      M.save_to_file()
    end,
  })
  
  -- Set up default autocommands if enabled
  if M.config.setup_default_autocmd then
    M.add_default_autocmd()
  end
end

return M
