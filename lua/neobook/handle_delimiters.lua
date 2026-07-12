local M = {}

local delimiter_ns = vim.api.nvim_create_namespace ('neobook_delimiters')

local code_delimiter_symbol = '+'
local md_delimiter_symbol = '='
local output_delimiter_symbol = '-'
local active_upper_delimiter_symbol = 'v'
local active_lower_delimiter_symbol = '^'

local output_prefix = '<OUTPUT>'

local function get_prefix_and_symbol (delimiter_info)

	if delimiter_info.is_code_cell then
		if delimiter_info.delimiter_type == 0 then
			return '[' .. delimiter_info.exec_count .. ']', code_delimiter_symbol
		elseif delimiter_info.delimiter_type == 1 then
			return '', code_delimiter_symbol
		else
			return output_prefix, output_delimiter_symbol
		end
	else
		return '', md_delimiter_symbol
	end

end

local function set_delimiters (current_buf, current_win)

	local delimiter_extmark_dict = vim.b[current_buf].delimiter_extmark_dict

	local win_width = vim.api.nvim_win_get_width (current_win)

	for extmark_id, delimiter_info in ipairs (delimiter_extmark_dict) do
		local pos = vim.api.nvim_buf_get_extmark_by_id (current_buf, delimiter_ns, extmark_id, {})

		local prefix, symbol = get_prefix_and_symbol (delimiter_info)
		local delimiter_text = prefix .. string.rep (symbol, win_width - #prefix)

		vim.api.nvim_buf_set_extmark (current_buf, delimiter_ns, pos[1], 0, {
			id = extmark_id,
			virt_lines = { { { delimiter_text, 'Comment' } } },
			virt_lines_above = true,
			virt_lines_leftcol = true,
			right_gravity = false
		})
	end

end

local function register_delimiter_extmarks (delimiters_info_lis)

	local delimiter_extmark_dict = vim.b.delimiter_extmark_dict or {}

	for _, delimiter in ipairs (delimiters_info_lis) do
	-- for i = #delimiters_info_lis, 1, -1 do
		-- local delimiter = delimiters_info_lis[i]

		local extmark_id = vim.api.nvim_buf_set_extmark (0, delimiter_ns, delimiter.line_num, 0, {
			right_gravity = false
		})

			delimiter_extmark_dict[extmark_id] = {
				delimiter_type = delimiter.delimiter_type,
				is_code_cell = delimiter.is_code_cell,
				exec_count = delimiter.exec_count
			}
	end

	vim.b.delimiter_extmark_dict = delimiter_extmark_dict
	set_delimiters (0, 0)

	-- vim.api.nvim_clear_autocmds ({ group = vim.api.nvim_create_augroup ('neobook_images_' .. current_buf, { clear = true }), buffer = current_buf })


	vim.api.nvim_create_autocmd ('WinResized', {
		group = vim.api.nvim_create_augroup ('neobook_resize_ui', { clear = true }),
		callback = function ()
			local resized_windows = vim.v.event.windows

			if not resized_windows then return end

			for _, win_id in ipairs (resized_windows) do
				local buf_id = vim.api.nvim_win_get_buf (win_id)

				if vim.b[buf_id].delimiter_extmark_dict then
					set_delimiters (buf_id, win_id)
				end
			end

		end
	})

end

local function get_delimiter_ladder ()
	local delimiter_rows = {}
	local delimiter_extmarks = vim.api.nvim_buf_get_extmarks (0, delimiter_ns, 0, -1, {})
	local delimiter_extmark_dict = vim.b.delimiter_extmark_dict

	for _, delimiter_extmark_info in ipairs (delimiter_extmarks) do
		local mark_id = delimiter_extmark_info[1]
		local line_num = delimiter_extmark_info[2]

		if delimiter_extmark_dict[mark_id].delimiter_type ~= 0 then
			line_num = line_num - 1
		end

		table.insert (delimiter_rows, line_num)
	end

	table.sort (delimiter_rows)

	local ret = {}

	for i = #delimiter_rows - 1, 1, -1 do
		ret[delimiter_rows[i]] = delimiter_rows[i + 1]
	end

	return ret
end


M.register_delimiter_extmarks = register_delimiter_extmarks
M.set_delimiters = set_delimiters
M.get_delimiter_ladder = get_delimiter_ladder

return M
