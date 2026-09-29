-- Custom keymaps.
--
-- Drop a `<name>.lua` file in this directory and it is loaded automatically
-- (same pattern as `lua/custom/plugins/`), keeping personal keymaps separate
-- from kickstart's `lua/keymaps.lua`.
local keybinds_dir = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'custom', 'keybinds')
for file_name, type in vim.fs.dir(keybinds_dir, { follow = true }) do
  if (type == 'file' or type == 'link') and file_name:match '%.lua$' and file_name ~= 'init.lua' then
    local module = file_name:gsub('%.lua$', '')
    require('custom.keybinds.' .. module)
  end
end

-- vim: ts=2 sts=2 sw=2 et
