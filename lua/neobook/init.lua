local M = {}

local function render_notebook ()
	local lines = vim.api.nvim_buf_get_lines (0, 0, -1, false)
	local content = table.concat (lines, '\n')

	-- local buf = vim.api.nvim_create_buf (false, true)

	-- vim.api.nvim_command ('vsplit')
	-- vim.api.nvim_win_set_buf (0, buf)

	local ok, parsed = pcall (vim.fn.json_decode, content)
	if not ok or type (parsed) ~= 'table' or not parsed.cells then
		-- print ('Error: Current buffer is not a valid Jupyter Notebook')
		return
	end

	local display_lines = {}

	local split_width = vim.api.nvim_win_get_width (0) - 5
	local delimiter = string.rep ('+', split_width)

	for _, cell in ipairs (parsed.cells) do
		table.insert (display_lines, delimiter)
		
		if cell.cell_type == 'markdown' then
			table.insert (display_lines, '[ Markdown Cell ]')
		else
			local count = cell.execution_count and tostring (cell.execution_count) or ' '
			table.insert (display_lines, '[ Code Cell: ' .. count .. ' ]')
		end

		table.insert (display_lines, '')

		if cell.source then
			for _, line in ipairs (cell.source) do
				table.insert (display_lines, (line:gsub ('\n$', '')))
			end
		end

		if cell.outputs and #cell.outputs > 0 then
			table.insert (display_lines, '')
			table.insert (display_lines, '--- Output ---')

			for _, output in ipairs (cell.outputs) do
				if output.data and output.data['text/plain'] then
					for _, out_line in ipairs (output.data['text/plain']) do
						table.insert (display_lines, (out_line:gsub ('\n$', '')))
					end
				end
				
				if output.name == 'stdout' and output.text then
					for _, out_line in ipairs (output.text) do
						table.insert (display_lines, out_line:gsub ('\n$', ''))
					end
				end
			end
		end

		table.insert (display_lines, '')
	end
	
	table.insert (display_lines, delimiter)

	vim.api.nvim_buf_set_lines (0, 0, -1, false, display_lines)

	vim.api.nvim_set_option_value ('filetype', 'python', { buf = 0 })

end

function M.setup (opts)
	opts = opts or {}

	-- vim.api.nvim_create_user_command ('NeobookRender', render_notebook, {})
	
	vim.api.nvim_create_autocmd ('BufReadPost', {
		pattern = '*.ipynb',
		callback = function ()
			render_notebook ()
		end,
	})

end

return M
