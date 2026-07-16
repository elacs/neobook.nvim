--imports
local handle_delimiters = require ('neobook.handle_delimiters')


local M = {}

local cell_id_ns = vim.api.nvim_create_namespace ('neobook_cell_ids')

local function get_current_cursor_offset (desired_cell_id)
	local current_cursor_pos = vim.api.nvim_win_get_cursor (0)

	local cell_id_extmark_dict = vim.b.cell_id_extmark_dict

	for extmark_id, cell_id in ipairs (cell_id_extmark_dict) do
		if cell_id == desired_cell_id then
			local extmark_pos = vim.api.nvim_buf_get_extmark_by_id (0, cell_id_ns, extmark_id, {})

			return {
				[1] = current_cursor_pos[1] - extmark_pos[1],
				[2] = current_cursor_pos[2] - extmark_pos[2]
			}

		end
	end

end

local function set_current_cursor_offset (desired_cell_id, offset)

	local cell_id_extmark_dict = vim.b.cell_id_extmark_dict

	local extmark_pos = {1, 0}

	for extmark_id, cell_id in ipairs (cell_id_extmark_dict) do
		if cell_id == desired_cell_id then
			extmark_pos = vim.api.nvim_buf_get_extmark_by_id (0, cell_id_ns, extmark_id, {})

			break
		end
	end

	local delimiter_ladder = handle_delimiters.get_delimiter_ladder ()

	local line_num = math.min (extmark_pos[1] + offset[1], delimiter_ladder[extmark_pos[1]] + 1)

	local col = math.min (extmark_pos[2] + offset[2], #vim.api.nvim_buf_get_lines (0, line_num - 1, line_num, false)[1])

	-- print (line_num, col)

	vim.api.nvim_win_set_cursor (0, {
		[1] = line_num,
		[2] = col
	})
end

local function set_cursor_at_cell (desired_cell_id)
	local cell_id_extmark_dict = vim.b.cell_id_extmark_dict

	local extmark_pos = {0, 0}

	for extmark_id, cell_id in ipairs (cell_id_extmark_dict) do
		if cell_id == desired_cell_id then
			extmark_pos = vim.api.nvim_buf_get_extmark_by_id (0, cell_id_ns, extmark_id, {})

			break
		end
	end

	vim.api.nvim_win_set_cursor (0, {extmark_pos[1] + 1, 0})

end

local function get_current_cursor_position ()
	return vim.api.nvim_win_get_cursor (0)
end

local function set_current_cursor_position (pos)
	local max_line_num = vim.api.nvim_buf_line_count (0)

	local line_num = math.min (pos[1], max_line_num)

	local col = math.min (pos[2], #vim.api.nvim_buf_get_lines (0, line_num - 1, line_num, false)[1])

	vim.api.nvim_win_set_cursor (0, {
		[1] = line_num,
		[2] = col
	})
end


M.get_current_cursor_offset = get_current_cursor_offset
M.set_current_cursor_offset = set_current_cursor_offset
M.set_cursor_at_cell = set_cursor_at_cell
M.get_current_cursor_position = get_current_cursor_position
M.set_current_cursor_position = set_current_cursor_position

return M
