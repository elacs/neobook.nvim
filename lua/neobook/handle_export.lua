-- imports
local save_notebook = require ('neobook.save_notebook')


local M = {}

local function save_and_export_notebook (format)
	local filepath = vim.api.nvim_buf_get_name (0)

	if filepath == '' or not filepath:match ('%.ipynb') then
		vim.notify ('Current buffer is not a valid .ipynb file', vim.log.levels.WARN)
		return
	end

	save_notebook.save_notebook (filepath)

	local cmd = {'jupyter', 'nbconvert', '--to', format, filepath}

	if format == 'latex' then
		local base_dir = vim.fn.fnamemodify (filepath, ':h')
		local filename_no_ext = vim.fn.fnamemodify (filepath, ':t:r')

		local output_dir = base_dir .. '/' .. filename_no_ext .. '_tex'

		table.insert (cmd, '--output-dir')
		table.insert (cmd, output_dir)
	end


	vim.fn.jobstart (cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stderr = function (_, data, _)
			local err_msg = table.concat (data, '\n'):gsub ('%s+$', '')
			print (err_msg) -- nbconvert writes diagnostic/progress info to stderr
		end,
		on_exit = function (_, exit_code, _)
			if exit_code == 0 then
				vim.notify ('Successfully exported to ' .. format, vim.log.levels.INFO)
			else
				vim.notify ('Export failed', vim.log.levels.ERROR)
			end
		end,
	})

end


M.save_and_export_notebook = save_and_export_notebook

return M

