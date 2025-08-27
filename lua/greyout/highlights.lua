local M = {}
local config = require("greyout.config")

M.namespace = nil
M.fold_info = {}  -- Track folds for fold mode
M.created_folds = {}  -- Track actual fold IDs we've created

function M.setup()
  M.namespace = vim.api.nvim_create_namespace("greyout")
end

function M.add_highlight(bufnr, start_row, start_col, end_row, end_col)
  if not M.namespace then return end
  
  local mode = config.options.mode
  
  if mode == "grey" then
    -- Grey out the text
    vim.api.nvim_buf_set_extmark(bufnr, M.namespace, start_row, start_col, {
      end_row = end_row,
      end_col = end_col,
      hl_group = "GreyoutText",
      priority = 200,
      hl_mode = "combine",
    })
  elseif mode == "conceal" then
    -- Conceal text - hides content but leaves blank lines
    if start_row == end_row then
      -- Single line - conceal with placeholder
      vim.api.nvim_buf_set_extmark(bufnr, M.namespace, start_row, start_col, {
        end_row = end_row,
        end_col = end_col,
        conceal = config.options.conceal.placeholder,
        priority = 200,
      })
    else
      -- Multi-line block - conceal the content
      -- First line gets placeholder
      local first_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
      if first_line then
        vim.api.nvim_buf_set_extmark(bufnr, M.namespace, start_row, start_col, {
          end_row = start_row,
          end_col = #first_line,
          conceal = config.options.conceal.placeholder,
          priority = 200,
        })
      end
      
      -- Hide content on remaining lines (they'll appear blank)
      for row = start_row + 1, end_row do
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
        if line then
          vim.api.nvim_buf_set_extmark(bufnr, M.namespace, row, 0, {
            end_row = row,
            end_col = #line,
            conceal = "",
            priority = 200,
          })
        end
      end
    end
  elseif mode == "fold" then
    -- Fold mode - actually collapse lines using folds
    -- Store fold info to be applied later
    if not M.fold_info then
      M.fold_info = {}
    end
    if not M.fold_info[bufnr] then
      M.fold_info[bufnr] = {}
    end
    
    table.insert(M.fold_info[bufnr], {
      start_row = start_row,
      end_row = end_row,
    })
  end
end


function M.add_highlight_range(bufnr, range)
  local start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]
  M.add_highlight(bufnr, start_row, start_col, end_row, end_col)
end

function M.apply_folds(bufnr)
  -- Apply folds for fold mode
  if not M.fold_info[bufnr] or #M.fold_info[bufnr] == 0 then
    return
  end
  
  local win = vim.fn.bufwinid(bufnr)
  if win ~= -1 then
    -- Save current fold state
    local saved_foldmethod = vim.api.nvim_win_get_option(win, "foldmethod")
    local saved_foldlevel = vim.api.nvim_win_get_option(win, "foldlevel")
    
    -- Switch to manual fold method
    vim.api.nvim_win_set_option(win, "foldmethod", "manual")
    vim.api.nvim_win_set_option(win, "foldenable", true)
    
    -- Track which folds we create
    if not M.created_folds[bufnr] then
      M.created_folds[bufnr] = {}
    end
    
    -- Create folds and track them
    for _, fold in ipairs(M.fold_info[bufnr]) do
      local start_line = fold.start_row + 1
      local end_line = fold.end_row + 1
      
      -- Create the fold
      vim.cmd(string.format("silent! %d,%dfold", start_line, end_line))
      
      -- Store the fold range so we can delete it later
      table.insert(M.created_folds[bufnr], {
        start_line = start_line,
        end_line = end_line
      })
    end
    
    -- Close all our folds
    vim.api.nvim_win_set_option(win, "foldlevel", 0)
  end
end

function M.clear_folds(bufnr)
  -- Clear only the folds we created, leave other highlights intact
  if M.created_folds[bufnr] and #M.created_folds[bufnr] > 0 then
    local win = vim.fn.bufwinid(bufnr)
    if win ~= -1 then
      -- Save cursor position
      local cursor = vim.api.nvim_win_get_cursor(win)
      
      -- Delete only the folds we created
      for _, fold in ipairs(M.created_folds[bufnr]) do
        -- Position cursor at the fold and delete it
        vim.api.nvim_win_set_cursor(win, {fold.start_line, 0})
        vim.cmd("silent! normal! zd")
      end
      
      -- Restore cursor position
      vim.api.nvim_win_set_cursor(win, cursor)
    end
  end
  
  -- Clear fold tracking info
  M.fold_info[bufnr] = nil
  M.created_folds[bufnr] = nil
end

function M.clear_buffer(bufnr)
  if not M.namespace then return end
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  
  -- Clear our tracked folds
  if M.created_folds[bufnr] and #M.created_folds[bufnr] > 0 then
    local win = vim.fn.bufwinid(bufnr)
    if win ~= -1 then
      -- Save cursor position
      local cursor = vim.api.nvim_win_get_cursor(win)
      
      -- Delete only the folds we created
      for _, fold in ipairs(M.created_folds[bufnr]) do
        -- Position cursor at the fold and delete it
        vim.api.nvim_win_set_cursor(win, {fold.start_line, 0})
        vim.cmd("silent! normal! zd")
      end
      
      -- Restore cursor position
      vim.api.nvim_win_set_cursor(win, cursor)
    end
  end
  
  -- Clear fold tracking info
  M.fold_info[bufnr] = nil
  M.created_folds[bufnr] = nil
end

return M