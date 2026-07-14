-- imports
local render_notebook = require ('neobook.render_notebook')
local save_notebook = require ('neobook.save_notebook')
local handle_execution = require ('neobook.handle_execution')
local handle_cell_lifecycle = require ('neobook.handle_cell_lifecycle')


local M = {}

local function setup (opts)
	opts = opts or {}

	-- vim.api.nvim_create_user_command ('NeobookRender', render_notebook, {})

	vim.api.nvim_create_autocmd ('BufReadPost', {
		pattern = '*.ipynb',
		callback = function ()
			render_notebook.render_notebook ()
		end,
	})

	vim.api.nvim_create_autocmd ('BufWriteCmd', {
		pattern = '*.ipynb',
		callback = function (args)
			save_notebook.save_notebook (args.file)
		end,
	})

	vim.keymap.set ('n', '<leader>rx', handle_execution.execute_current_cell)

	vim.keymap.set ('n', '<leader>aa', function () handle_cell_lifecycle.create_new_cell (true) end)
	vim.keymap.set ('n', '<leader>bb', function () handle_cell_lifecycle.create_new_cell (false) end)
	vim.keymap.set ('n', '<leader>dd', handle_cell_lifecycle.delete_current_cell)
	vim.keymap.set ('n', '<leader>tt', handle_cell_lifecycle.toggle_current_cell_type)

end


M.setup = setup

return M
