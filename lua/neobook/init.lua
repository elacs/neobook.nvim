-- imports
local render_notebook = require ('neobook.render_notebook')
local save_notebook = require ('neobook.save_notebook')
local handle_execution = require ('neobook.handle_execution')


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

end


M.setup = setup

return M
