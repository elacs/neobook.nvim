-- imports
local handle_delimiters = require ('neobook.handle_delimiters')
local save_notebook = require ('neobook.save_notebook')
local render_notebook = require ('neobook.render_notebook')


local M = {}

local cell_id_ns = vim.api.nvim_create_namespace ('neobook_cell_ids')

local curr_execution_outputs_dict = {}
local curr_execution_cell_id_dict = {}
local jupyter_kernel_manager_job_id_dict = {}

local function get_current_cell_id ()
	local cursor_line = vim.api.nvim_win_get_cursor (0)[1] - 1

	local cell_id_extmark_dict = vim.b.cell_id_extmark_dict
	local cell_id_extmarks = vim.api.nvim_buf_get_extmarks (0, cell_id_ns, 0, -1, {})

	table.sort (cell_id_extmarks, function (a, b) return a[2] < b[2] end)

	local ret = -1

	for _, mark_info in ipairs (cell_id_extmarks) do
		if mark_info[2] <= cursor_line then
			ret = cell_id_extmark_dict[mark_info[1]]
		else
			break
		end
	end

	return ret
end

local function get_current_upper_delimiter_line_num ()
	local cursor_line = vim.api.nvim_win_get_cursor (0)[1] - 1

	local cell_id_extmarks = vim.api.nvim_buf_get_extmarks (0, cell_id_ns, 0, -1, {})

	table.sort (cell_id_extmarks, function (a, b) return a[2] < b[2] end)

	local ret = -1

	for _, mark_info in ipairs (cell_id_extmarks) do
		local line_num = mark_info[2]

		if line_num <= cursor_line then
			ret = line_num
		else
			break
		end
	end

	return ret

end

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

local function get_current_cell_source ()

	local upper_delimiter_line_num = get_current_upper_delimiter_line_num ()

	local delimiter_ladder = handle_delimiters.get_delimiter_ladder ()

	local end_row = delimiter_ladder[upper_delimiter_line_num]

	return vim.api.nvim_buf_get_lines (0, upper_delimiter_line_num, end_row + 1, false)
end

local function save_to_notebook_json_and_render_outputs (cell_id, outputs)
	local current_cursor_offset = get_current_cursor_offset (cell_id)

	save_notebook.save_render_buffer_sources_to_notebook_json ()
	save_notebook.save_outputs_to_notebook_json (cell_id, outputs)

	render_notebook.render_notebook_from_notebook_json () -- implement a method that only renders the outputs of the cell

	set_current_cursor_offset (cell_id, current_cursor_offset)
end

local function get_jupyter_kernel_manager_job_id ()
	local current_buf = vim.api.nvim_get_current_buf ()

	if jupyter_kernel_manager_job_id_dict[current_buf] then return jupyter_kernel_manager_job_id_dict[current_buf] end

	local python_script = vim.fn.fnamemodify (debug.getinfo (1).source:sub (2), ':h') .. '/jupyter_kernel_manager.py'

	local curr_line = ''

	curr_execution_cell_id_dict[current_buf] = nil
	curr_execution_outputs_dict[current_buf] = {}

	local job_id = vim.fn.jobstart ({ 'python3', python_script }, {
		stdout_buffered = false,
		on_stdout = function (_, data, _)

			for _, line in ipairs (data) do
				if line ~= '' then

					curr_line = curr_line .. line
					local success, decoded = pcall (vim.json.decode, curr_line)

					if success then

						if decoded.output_type == 'neobook_status' and decoded.state == 'idle' then
							if curr_execution_cell_id_dict[current_buf] then
								save_to_notebook_json_and_render_outputs (curr_execution_cell_id_dict[current_buf], curr_execution_outputs_dict[current_buf])

								curr_execution_cell_id_dict[current_buf] = nil
								curr_execution_outputs_dict[current_buf] = {}
							end
						else
							if curr_execution_cell_id_dict[current_buf] then
								table.insert (curr_execution_outputs_dict[current_buf], decoded)
								-- print (vim.inspect (curr_execution_outputs_dict[current_buf]))
								save_to_notebook_json_and_render_outputs (curr_execution_cell_id_dict[current_buf], curr_execution_outputs_dict[current_buf])
							end
						end

						curr_line = ''

					end
				end
			end
		end,
		on_stderr = function (_, data, _)
			for _, line in ipairs (data) do
				if line~= '' then vim.notify ('Python Error: ' .. line, vim.log.levels.ERROR) end
			end
		end,
		on_exit = function ()
			jupyter_kernel_manager_job_id_dict[current_buf] = nil
			vim.notify ('Jupyter Kernel stopped', vim.log.levels.INFO)
		end
	})

	jupyter_kernel_manager_job_id_dict[current_buf] = job_id

	vim.api.nvim_create_autocmd ({'BufDelete', 'BufWipeout'}, {
		buffer = current_buf,
		callback = function ()
			if vim.b[current_buf].jupyter_kernel_manager_job_id then
				vim.fn.jobstop (vim.b[current_buf].jupyter_kernel_manager_job_id)
			end
		end,
		once = true
	})

	return job_id
end

local function execute_current_cell ()
	local current_cell_id = get_current_cell_id ()
	local current_cell_source = get_current_cell_source ()

	local jupyter_kernel_manager_job_id = get_jupyter_kernel_manager_job_id ()

	local current_buf = vim.api.nvim_get_current_buf ()
	curr_execution_cell_id_dict[current_buf] = current_cell_id
	curr_execution_outputs_dict[current_buf] = {}

	save_to_notebook_json_and_render_outputs (current_cell_id, curr_execution_outputs_dict[current_buf])

	local code_str = table.concat (current_cell_source, '\n')
	local request = vim.fn.json_encode ({ code = code_str }) .. '\n'
	-- print (request)
	vim.fn.chansend (jupyter_kernel_manager_job_id, request)

end


M.execute_current_cell = execute_current_cell

return M
