-- nvim on plain lazy.nvim: no distro, native LSP (lua/lsp.lua). Every server
-- and formatter is a normal binary on PATH (pacman, or npm via mise; the
-- installer's phases/25-dev.sh lists them). No Mason. Colours come from the
-- Ouranos palette via colors/palette.lua.
--
--   lua/config/options.lua    editor options
--   lua/config/lazy.lua       lazy.nvim bootstrap + plugin specs (lua/plugins/*)
--   lua/config/keymaps.lua    global keymaps (LazyVim-compatible muscle memory)
--   lua/config/autocmds.lua   autocommands
--   lua/config/statusline.lua the statusline
--   lua/lsp.lua               servers, diagnostics, LspAttach maps
--   lua/ai/herdr.lua          send code to the Codex/Claude panes in herdr
vim.loader.enable()

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("config.statusline")
