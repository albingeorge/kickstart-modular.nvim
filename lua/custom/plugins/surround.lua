local function gh(repo) return 'https://github.com/' .. repo end

-- [[ Surround ]]
--  Add/change/delete surrounding pairs: `cs"'` `ds(` `ysiw]`
--  See `:help surround`
--
--  NOTE: `kickstart.plugins.mini` also loads `mini.surround`, which binds
--  `sa`/`sd`/`sr` instead. Both can coexist; drop one if you only want a
--  single set of keys.
vim.pack.add { gh 'tpope/vim-surround' }

-- vim: ts=2 sts=2 sw=2 et
