-- imports
local handle_delimiters = require ('neobook.handle_delimiters')


local M = {}

local cell_id_ns = vim.api.nvim_create_namespace ('neobook_cell_ids')

local function save_render_buffer_sources_to_notebook_json ()
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

		local new_cell_source = {}
		for row = start_row + 1, end_row do
			local line = lines[row]

			table.insert (new_cell_source, line .. '\n')
		end

		if lines[end_row + 1] ~= '' then
			table.insert (new_cell_source, lines[end_row + 1])
		end

		for _, cell in ipairs (notebook_json.cells) do
			if cell.id == cell_id then
				cell.source = new_cell_source
				break
			end
		end

	end

	vim.b.notebook_json = notebook_json
end

local function save_outputs_to_notebook_json (cell_id, outputs)

	local notebook_json = vim.b.notebook_json

	for _, cell in ipairs (notebook_json.cells) do
		if cell.id == cell_id then
			cell.outputs = outputs
			break
		end
	end

	vim.b.notebook_json = notebook_json
end

local function save_notebook_json_to_disk (filepath)
	local updated_json = vim.fn.json_encode (vim.b.notebook_json)

	local file = io.open (filepath, 'w')

	if file then
		file:write (updated_json)
		file:close ()
		vim.api.nvim_set_option_value ('modified', false, { buf = 0 })
	end

end

local function save_notebook (filepath)

	-- local notebook_json = vim.b.notebook_json
	-- for _, cell in ipairs (notebook_json.cells) do
	-- 	print (#cell.outputs)
	-- end

	save_render_buffer_sources_to_notebook_json ()
	save_notebook_json_to_disk (filepath)

end


M.save_notebook = save_notebook
M.save_render_buffer_sources_to_notebook_json = save_render_buffer_sources_to_notebook_json
M.save_outputs_to_notebook_json = save_outputs_to_notebook_json

return M
