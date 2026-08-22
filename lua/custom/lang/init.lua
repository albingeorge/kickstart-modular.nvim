-- Per-language configuration.
--
-- Drop a `<language>.lua` file in this directory and it is loaded automatically
-- (same pattern as `lua/custom/plugins/`). Each module owns everything for its
-- language: LSP server, formatter, treesitter parser, filetype options.
--
-- `util.lua` is a shared helper module, not a language, so it is skipped.
local skip = { ['init.lua'] = true, ['util.lua'] = true }

local lang_dir = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'custom', 'lang')
for file_name, type in vim.fs.dir(lang_dir, { follow = true }) do
  if (type == 'file' or type == 'link') and file_name:match '%.lua$' and not skip[file_name] then
    local module = file_name:gsub('%.lua$', '')
    require('custom.lang.' .. module)
  end
end

-- vim: ts=2 sts=2 sw=2 et
