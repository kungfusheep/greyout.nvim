local M = {}

M.defaults = {
  auto_enable = true,
  mode = "grey", -- "grey", "conceal", "fold", or "off"
  keymaps = {
    enabled = true,
    prefix = "<leader>gc", -- Base prefix for keymaps
    mappings = {
      toggle = "t",     -- <leader>gct - Toggle on/off
      cycle = "c",      -- <leader>gcc - Cycle through modes
      grey = "g",       -- <leader>gcg - Set grey mode
      conceal = "h",    -- <leader>gch - Hide/conceal mode
      fold = "f",       -- <leader>gcf - Fold mode
      off = "o",        -- <leader>gco - Turn off
      refresh = "r",    -- <leader>gcr - Refresh
    }
  },
  languages = {
    go = {
      enabled = true,
      patterns = {
        error_handling = true,
        logging = true,
      }
    },
  },
  highlight = {
    link = "Comment",
    custom = nil,
  },
  conceal = {
    placeholder = "...", -- What to show instead of concealed text
    show_on_cursor = true, -- Show text when cursor is on the line
  },
  custom_patterns = {},
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  
  -- Always reset the highlight group when setting up
  if M.options.highlight.custom then
    vim.api.nvim_set_hl(0, "GreyoutText", M.options.highlight.custom)
  else
    vim.api.nvim_set_hl(0, "GreyoutText", { link = M.options.highlight.link })
  end
end

function M.get_language_config(lang)
  return M.options.languages[lang]
end

function M.is_pattern_enabled(lang, pattern_name)
  local lang_config = M.get_language_config(lang)
  if not lang_config or not lang_config.enabled then
    return false
  end
  return lang_config.patterns[pattern_name] == true
end

return M