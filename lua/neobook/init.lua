-- imports
local render_notebook = require ('neobook.render_notebook')
local save_notebook = require ('neobook.save_notebook')
local handle_execution = require ('neobook.handle_execution')
local handle_cell_lifecycle = require ('neobook.handle_cell_lifecycle')
local handle_export = require ('neobook.handle_export')
local initialize_notebook = require ('neobook.initialize_notebook')


local M = {}

local function attach_neobook (bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf ()

	if vim.b[bufnr].neobook_attached then return end
	vim.b[bufnr].neobook_attached = true

	render_notebook.render_notebook ()
end

local function setup (opts)
	opts = opts or {}

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

	vim.keymap.set ('n', '<leader>rr', handle_execution.execute_current_cell)

	vim.keymap.set ('n', '<leader>aa', function () handle_cell_lifecycle.create_new_cell (true) end)
	vim.keymap.set ('n', '<leader>bb', function () handle_cell_lifecycle.create_new_cell (false) end)
	vim.keymap.set ('n', '<leader>dd', handle_cell_lifecycle.delete_current_cell)
	vim.keymap.set ('n', '<leader>tt', handle_cell_lifecycle.toggle_current_cell_type)

	vim.api.nvim_create_user_command ('ExportPdf', function () handle_export.save_and_export_notebook ('pdf') end, {})
	vim.api.nvim_create_user_command ('ExportLatex', function () handle_export.save_and_export_notebook ('latex') end, {})

	vim.api.nvim_create_user_command ('KillKernel', handle_execution.kill_jupyter_kernel, {})
	vim.api.nvim_create_user_command ('RunAll', handle_execution.execute_all_cells, {})
	-- vim.api.nvim_create_user_command ('InitializeNotebook', initialize_notebook.initialize_notebook, {})

	vim.api.nvim_create_autocmd ('FileType', {
		pattern = 'ipynb',
		callback = function (ev)
			attach_neobook (ev.buf)
		end
	})

	if vim.bo.filetype == 'ipynb' then
		attach_neobook (vim.api.nvim_get_current_buf ())
	end
end


M.setup = setup

return M
