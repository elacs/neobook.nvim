-- imports
local get_delimiters = require ('neobook.get_delimiters')


local M = {}

local ns_id = vim.api.nvim_create_namespace ('neobook_cells')

local function save_notebook (filepath)

	local notebook_json = vim.b.notebook_json
	local extmark_dict = vim.b.extmark_dict

	if not notebook_json or not extmark_dict then return end

	local lines = vim.api.nvim_buf_get_lines (0, 0, -1, false)

	local extmarks = vim.api.nvim_buf_get_extmarks (0, ns_id, 0, -1, {})

	for i, mark_info in ipairs (extmarks) do
		local mark_id = mark_info[1]
		local start_row = mark_info[2]

		local end_row = #lines
		if extmarks[i + 1] then
			end_row = extmarks[i + 1][2]
		end

		local cell_id = extmark_dict[mark_id]

		local raw_cell_text = {}
		for row = start_row + 2, end_row - 1 do
			local line = lines[row]

			if line == get_delimiters.output_delimiter then break end

			table.insert (raw_cell_text, line .. '\n')
		end

		for _, cell in ipairs (notebook_json.cells) do
			if cell.id == cell_id then
				cell.source = raw_cell_text
				break
			end
		end

	end

	local updated_json = vim.fn.json_encode (notebook_json)

	local file = io.open (filepath, 'w')

	if file then
		file:write (updated_json)
		file:close ()
		vim.api.nvim_set_option_value ('modified', false, { buf = 0 })
	end

end


M.save_notebook = save_notebook

return M
