-- imports
local handle_delimiters = require ('neobook.handle_delimiters')
local save_notebook = require ('neobook.save_notebook')
local render_notebook = require ('neobook.render_notebook')
local handle_cursor_pos = require ('neobook.handle_cursor_pos')

local M = {}

local cell_id_ns = vim.api.nvim_create_namespace ('neobook_cell_ids')

local curr_execution_outputs_dict = {}
local curr_execution_cell_id_dict = {}
local jupyter_kernel_manager_job_id_dict = {}
local curr_execution_count_dict = {}
local kernel_execution_state_dict = {}
local execution_queue_dict = {}

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

local function get_cell_type (cell_id)

	local notebook_json = vim.b.notebook_json

	for _, cell in ipairs (notebook_json.cells) do
		if cell.id == cell_id then
			return cell.cell_type
		end
	end
end

local function get_cell_source (desired_cell_id)

	local cell_id_extmark_dict = vim.b.cell_id_extmark_dict

	local start_row = -1
	for mark_id, cell_id in ipairs (cell_id_extmark_dict) do
		if cell_id == desired_cell_id then
			start_row = vim.api.nvim_buf_get_extmark_by_id (0, cell_id_ns, mark_id, {})[1]
			break
		end
	end

	local delimiter_ladder = handle_delimiters.get_delimiter_ladder ()

	local end_row = delimiter_ladder[start_row]

	return vim.api.nvim_buf_get_lines (0, start_row, end_row + 1, false)
end

local function set_cell_execution_count (cell_id, execution_count)
	local notebook_json = vim.b.notebook_json

	for _, cell in ipairs (notebook_json.cells) do
		if cell.id == cell_id then
			cell.execution_count = execution_count
		end
	end

	vim.b.notebook_json = notebook_json

end

local function save_to_notebook_json_and_render_outputs (cell_id, outputs)
	-- local current_cursor_offset = handle_cursor_pos.get_current_cursor_offset (cell_id)
	local current_cursor_position = handle_cursor_pos.get_current_cursor_position ()

	save_notebook.save_render_buffer_sources_to_notebook_json ()
	save_notebook.save_outputs_to_notebook_json (cell_id, outputs)

	render_notebook.render_notebook_from_notebook_json () -- implement a method that only renders the outputs of the cell

	-- handle_cursor_pos.set_current_cursor_offset (cell_id, current_cursor_offset)
	handle_cursor_pos.set_current_cursor_position (current_cursor_position)
end

local function feed_kernel ()
	local current_buf = vim.api.nvim_get_current_buf ()

	if kernel_execution_state_dict[current_buf] or #execution_queue_dict[current_buf] == 0 then return end

	local request = execution_queue_dict[current_buf][1].request
	local cell_id = execution_queue_dict[current_buf][1].cell_id
	-- print (vim.inspect (request))
	curr_execution_cell_id_dict[current_buf] = cell_id
	curr_execution_outputs_dict[current_buf] = {}
	curr_execution_count_dict[current_buf] = curr_execution_count_dict[current_buf] + 1

	-- set_cell_execution_count (cell_id, curr_execution_count_dict[current_buf])

	local jupyter_kernel_manager_job_id = jupyter_kernel_manager_job_id_dict[current_buf]
	vim.fn.chansend (jupyter_kernel_manager_job_id, request)

	kernel_execution_state_dict[current_buf] = true
	table.remove (execution_queue_dict[current_buf], 1)

end

local function get_jupyter_kernel_manager_job_id ()
	local current_buf = vim.api.nvim_get_current_buf ()

	if jupyter_kernel_manager_job_id_dict[current_buf] then return jupyter_kernel_manager_job_id_dict[current_buf] end

	local python_script = vim.fn.fnamemodify (debug.getinfo (1).source:sub (2), ':h') .. '/jupyter_kernel_manager.py'

	local curr_line = ''

	curr_execution_cell_id_dict[current_buf] = nil
	curr_execution_outputs_dict[current_buf] = {}
	curr_execution_count_dict[current_buf] = 0
	execution_queue_dict[current_buf] = {}
	kernel_execution_state_dict[current_buf] = false


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
								set_cell_execution_count (curr_execution_cell_id_dict[current_buf], curr_execution_count_dict[current_buf])

								save_to_notebook_json_and_render_outputs (curr_execution_cell_id_dict[current_buf], curr_execution_outputs_dict[current_buf])

								curr_execution_cell_id_dict[current_buf] = nil
								curr_execution_outputs_dict[current_buf] = {}
								kernel_execution_state_dict[current_buf] = false

								feed_kernel ()
							end
						else
							if curr_execution_cell_id_dict[current_buf] then
								table.insert (curr_execution_outputs_dict[current_buf], decoded)
								set_cell_execution_count (curr_execution_cell_id_dict[current_buf], -1)

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
			if jupyter_kernel_manager_job_id_dict[current_buf] then
				vim.fn.jobstop (jupyter_kernel_manager_job_id_dict[current_buf])
			end
		end,
		once = true
	})

	return job_id
end

local function kill_jupyter_kernel ()
	local current_buf = vim.api.nvim_get_current_buf ()

	if jupyter_kernel_manager_job_id_dict[current_buf] then
		vim.fn.jobstop (jupyter_kernel_manager_job_id_dict[current_buf])
	end
end

local function execute_cell (cell_id)
	local cell_source = get_cell_source (cell_id)

	local _ = get_jupyter_kernel_manager_job_id ()

	local current_buf = vim.api.nvim_get_current_buf ()

	set_cell_execution_count (cell_id, -1)
	save_to_notebook_json_and_render_outputs (cell_id, {})

	local code_str = table.concat (cell_source, '\n')
	local request = vim.fn.json_encode ({ code = code_str }) .. '\n'

	execution_queue_dict[current_buf] = execution_queue_dict[current_buf] or {}

	table.insert (execution_queue_dict[current_buf], {
		request = request,
		cell_id = cell_id
	})

	feed_kernel ()

end

local function execute_current_cell ()
	local current_cell_id = get_current_cell_id ()

	local current_cell_type = get_cell_type (current_cell_id)
	if current_cell_type ~= 'code' then
		vim.notify ('Neobook Error: Not a code cell', vim.log.levels.ERROR, {})
		return
	end

	execute_cell (current_cell_id)
end

local function execute_all_cells ()
	local notebook_json = vim.b.notebook_json

	for _, cell in ipairs (notebook_json.cells) do
		if cell.cell_type == 'code' then
			execute_cell (cell.id)
		end
	end

end


M.get_current_cell_id = get_current_cell_id
M.execute_current_cell = execute_current_cell
M.kill_jupyter_kernel = kill_jupyter_kernel
M.execute_all_cells = execute_all_cells

return M
