-- imports
local render_notebook = require ('neobook.render_notebook')
local save_notebook = require ('neobook.save_notebook')


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

	-- vim.api.nvim_create_autocmd ('BufWriteCmd', {
	-- 	pattern = '*.ipynb',
	-- 	callback = function (args)
	-- 		save_notebook.save_notebook (args.file)
	-- 	end,
	-- })

end


M.setup = setup

return M
