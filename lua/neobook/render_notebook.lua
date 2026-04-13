-- imports
local get_delimiters = require ('neobook.get_delimiters')


local M = {}

local function concat_tables (a, b)
	for i = 1, #b do
		a[#a + 1] = b[i]
	end
end

local function notecell_to_display_lines (notecell)
	
	local is_code_cell = notecell.cell_type == 'code'

	local delimiter = get_delimiters.get_delimiter (is_code_cell)

	local ret = {}
	
	-- table.insert (ret, delimiter)

	if is_code_cell then
		local exec_count = notecell.execution_count and tostring (notecell.execution_count) or ''

		table.insert (ret, get_delimiters.get_code_cell_upper_delimiter (exec_count))
	else
		table.insert (ret, delimiter)
	end

	if notecell.source then
		for _, line in ipairs (notecell.source) do
			table.insert (ret, (line:gsub ('\n$', '')))
		end
	end

	if notecell.outputs and #notecell.outputs > 0 then
		table.insert (ret, '')
		table.insert (ret, '--- OUTPUT ---')
		
		for _, output in ipairs (notecell.outputs) do
			if output.data and output.data['text/plain'] then
				for _, out_line in ipairs (output.data['text/plain']) do
					table.insert (ret, (out_line:gsub ('\n$', '')))
				end
			end

			if output.name == 'stdout' and output.text then
				for _, out_line in ipairs (output.text) do
					table.insert (ret, (out_line:gsub ('\n$', '')))
				end
			end

		end

	end

	table.insert (ret, delimiter)

	return ret

end

local function render_notebook ()
	local lines = vim.api.nvim_buf_get_lines (0, 0, -1, false)
	local content = table.concat (lines, '\n')

	local ok, parsed = pcall (vim.fn.json_decode, content)
	if not ok or type (parsed) ~= 'table' or not parsed.cells then
		-- print ('Error: Current buffer is not a valid Jupyter Notebook')
		return
	end

	local display_lines = {}

	for _, cell in ipairs (parsed.cells) do
		concat_tables (display_lines, notecell_to_display_lines (cell))
	end

	vim.api.nvim_buf_set_lines (0, 0, -1, false, display_lines)

	vim.api.nvim_set_option_value ('filetype', 'python', { buf = 0 })

end


M.render_notebook = render_notebook

return M
