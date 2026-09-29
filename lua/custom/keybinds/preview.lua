-- [[ Yank preview window ]]
--  `yip` yanks the whole contents of the open preview window: a `:pedit`-style
--  preview window, or a floating preview such as LSP hover (`K`), a diagnostic
--  float or a gitsigns hunk preview.
--
--  When no preview is open, `yip` falls back to its usual meaning (yank inner
--  paragraph, through Yanky), so the built-in motion keeps working.

--- Find the preview window in the current tabpage.
--- Prefers a real 'previewwindow'; otherwise the top-most focusable float
--- (non-focusable floats are usually notifications/status widgets).
---@return integer|nil
local function find_preview_win()
  local current = vim.api.nvim_get_current_win()
  local best, best_zindex

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].previewwindow then return win end

    local config = vim.api.nvim_win_get_config(win)
    if win ~= current and config.relative ~= '' and config.focusable ~= false then
      local zindex = config.zindex or 50
      if not best or zindex > best_zindex then
        best, best_zindex = win, zindex
      end
    end
  end

  return best
end

vim.keymap.set('n', 'yid', function()
  local win = find_preview_win()
  if not win then
    local count = vim.v.count > 0 and tostring(vim.v.count) or ''
    local keys = vim.keycode('"' .. vim.v.register .. count .. '<Plug>(YankyYank)ip')
    vim.api.nvim_feedkeys(keys, 'm', false)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
  vim.fn.setreg(vim.v.register, lines, 'l')
  vim.notify(('Yanked %d lines from preview window'):format(#lines), vim.log.levels.INFO)
end, { desc = '[Y]ank [I]n [P]review window (falls back to yank inner paragraph)' })

-- vim: ts=2 sts=2 sw=2 et
