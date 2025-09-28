local M = {
}

M.config = {
  mappings = {
    add_pos = '<LEADER>;',
    jump_back = '<C-o>',
    jump_forward = '<C-i>',
  },
}

function M.add_pos()
end

function M.jump_back()
end

function M.jump_forward()
end

function M.setup_mappings()
  local opts = { noremap = true, silent = true }

  vim.api.nvim_set_keymap("x",
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

  M.reset()
end

return M
