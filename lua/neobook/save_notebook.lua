-- imports
local handle_delimiters = require ('neobook.handle_delimiters')


local M = {}

local cell_id_ns = vim.api.nvim_create_namespace ('neobook_cell_ids')

local function save_notebook (filepath)

	local notebook_json = vim.b.notebook_json
	local cell_id_extmark_dict = vim.b.cell_id_extmark_dict

	if not notebook_json or not cell_id_extmark_dict then return end

	local delimiter_ladder = handle_delimiters.get_delimiter_ladder ()

	local lines = vim.api.nvim_buf_get_lines (0, 0, -1, false)

	local cell_id_extmarks = vim.api.nvim_buf_get_extmarks (0, cell_id_ns, 0, -1, {})

	for _, mark_info in ipairs (cell_id_extmarks) do
		local mark_id = mark_info[1]
		local start_row = mark_info[2]

		local end_row = delimiter_ladder[start_row]
		-- print (start_row, end_row)

		local cell_id = cell_id_extmark_dict[mark_id]

		local raw_cell_text = {}
		for row = start_row + 1, end_row do
			local line = lines[row]

			table.insert (raw_cell_text, line .. '\n')
		end

		if lines[end_row + 1] ~= '' then
			table.insert (raw_cell_text, lines[end_row + 1])
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
