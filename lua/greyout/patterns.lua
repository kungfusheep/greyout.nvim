local M = {}
local config = require("greyout.config")

M.language_modules = {}

function M.setup()
  M.language_modules.go = require("greyout.languages.go")
end

function M.has_patterns(filetype)
  local lang_config = config.get_language_config(filetype)
  return lang_config and lang_config.enabled and M.language_modules[filetype] ~= nil
end

function M.apply_patterns(bufnr, filetype, root)
  local lang_module = M.language_modules[filetype]
  if not lang_module then return end
  
  if lang_module.apply_patterns then
    lang_module.apply_patterns(bufnr, root)
  end
  
  M.apply_custom_patterns(bufnr, filetype, root)
end

function M.apply_custom_patterns(bufnr, filetype, root)
  local custom = config.options.custom_patterns[filetype]
  if not custom then return end
  
  local highlights = require("greyout.highlights")
  local lang = vim.treesitter.language.get_lang(filetype)
  if not lang then return end
  
  for pattern_name, query_string in pairs(custom) do
    local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
    if ok then
      for _, match, _ in query:iter_matches(root, bufnr, 0, -1) do
        for id, node in pairs(match) do
          local start_row, start_col, end_row, end_col = node:range()
          highlights.add_highlight(bufnr, start_row, start_col, end_row, end_col)
        end
      end
    else
      vim.notify("Greyout: Invalid custom pattern '" .. pattern_name .. "': " .. query, vim.log.levels.WARN)
    end
  end
end

return M