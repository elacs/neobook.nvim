local M = {}

local code_delimiter_symbol = '+'
local md_delimiter_symbol = '='
local output_delimiter_symbol = '-'
local active_upper_delimiter_symbol = 'v'
local active_lower_delimiter_symbol = '^'

local function get_pane_width ()
	return vim.api.nvim_win_get_width (0) - 5
end

local function get_delimiter (is_code_cell)
	if is_code_cell then
		return string.rep (code_delimiter_symbol, get_pane_width ())
	else
		return string.rep (md_delimiter_symbol, get_pane_width ())
	end
end

local function get_code_cell_upper_delimiter (exec_count)
	local prefix = '[ ' .. exec_count .. ' ]'
	local suffix = string.rep (code_delimiter_symbol, get_pane_width () - #prefix)

	return prefix .. suffix
end


M.get_delimiter = get_delimiter
M.get_code_cell_upper_delimiter = get_code_cell_upper_delimiter

return M
