-- imports
local handle_execution = require ('neobook.handle_execution')
local render_notebook = require ('neobook.render_notebook')
local handle_cursor_pos = require ('neobook.handle_cursor_pos')


local M = {}

local function generate_unique_cell_id ()
	local cell_id_format = {8, 4, 4, 4, 12}
	local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'

	local parts = {}

	for _, l in ipairs (cell_id_format) do
		local part = ''

		for _ = 1, l do
			local rand_idx = math.random (1, #chars)
			part = part .. chars:sub (rand_idx, rand_idx)
		end

		table.insert (parts, part)
	end

	local ret = table.concat (parts, '-')

	local notebook_json = vim.b.notebook_json

	if notebook_json and notebook_json.cells then
		for _, cell in ipairs (notebook_json.cells) do
			if cell.id == ret then return generate_unique_cell_id () end
		end
	end

	return ret
end

local function create_new_cell (above)

	local current_cell_id = handle_execution.get_current_cell_id ()

	local current_cursor_offset = handle_cursor_pos.get_current_cursor_offset (current_cell_id)

	local blank_cell_template = {
		cell_type = 'code',
		id = '',
		metadata = vim.empty_dict (),
		outputs = {},
		source = {}
	}

	blank_cell_template.id = generate_unique_cell_id ()

	local notebook_json = vim.b.notebook_json

	local insert_idx = -1
	for i, cell in ipairs (notebook_json.cells) do
		if cell.id == current_cell_id then
			insert_idx = i
			break
		end
	end

	if not above then insert_idx = insert_idx + 1 end

	table.insert (notebook_json.cells, insert_idx, blank_cell_template)
	vim.b.notebook_json = notebook_json

	render_notebook.render_notebook_from_notebook_json ()

	handle_cursor_pos.set_current_cursor_offset (current_cell_id, current_cursor_offset)

end

local function get_neighbouring_cell_id (current_cell_id)

	local notebook_json = vim.b.notebook_json
	for i, cell in ipairs (notebook_json.cells) do
		if cell.id == current_cell_id then
			if i == #notebook_json.cells then
				return notebook_json.cells[i - 1].id
			else
				return notebook_json.cells[i + 1].id
			end

			break
		end
	end

end

local function delete_current_cell ()
	local current_cell_id = handle_execution.get_current_cell_id ()

	local neighbouring_cell_id = get_neighbouring_cell_id (current_cell_id)

	local notebook_json = vim.b.notebook_json

	local delete_idx = -1
	for i, cell in ipairs (notebook_json.cells) do
		if cell.id == current_cell_id then
			delete_idx = i
			break
		end
	end

	table.remove (notebook_json.cells, delete_idx)
	vim.b.notebook_json = notebook_json

	render_notebook.render_notebook_from_notebook_json ()

	handle_cursor_pos.set_cursor_at_cell (neighbouring_cell_id)
end

local function toggle_current_cell_type ()
	local current_cell_id = handle_execution.get_current_cell_id ()

	local current_cursor_offset = handle_cursor_pos.get_current_cursor_offset (current_cell_id)


	local notebook_json = vim.b.notebook_json

	for _, cell in ipairs (notebook_json.cells) do

		if cell.id == current_cell_id then
			if cell.cell_type == 'code' then
				cell.cell_type = 'markdown'
				cell.outputs = nil
				cell.execution_count = nil

			elseif cell.cell_type == 'markdown' then
				cell.cell_type = 'code'
				cell.outputs = {}

			end

			break
		end

	end

	vim.b.notebook_json = notebook_json

	render_notebook.render_notebook_from_notebook_json ()

	handle_cursor_pos.set_current_cursor_offset (current_cell_id, current_cursor_offset)

end


M.create_new_cell = create_new_cell
M.delete_current_cell = delete_current_cell
M.toggle_current_cell_type = toggle_current_cell_type

return M
