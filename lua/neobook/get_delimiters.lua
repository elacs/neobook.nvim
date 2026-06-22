local M = {}

local code_delimiter_symbol = '+'
local md_delimiter_symbol = '='
local output_delimiter_symbol = '-'
local active_upper_delimiter_symbol = 'v'
local active_lower_delimiter_symbol = '^'

local function get_pane_width ()
	return vim.api.nvim_win_get_width (0) - 5
end

local function get_code_cell_upper_delimiter (exec_count)
	local prefix = '[' .. exec_count .. ']'
	local suffix = string.rep (code_delimiter_symbol, get_pane_width () - #prefix)

	return prefix .. suffix
end

local function get_delimiters (is_code_cell, exec_count)
	local ret = {}

	if is_code_cell then
		ret.upper = get_code_cell_upper_delimiter (exec_count)
		ret.lower = string.rep (code_delimiter_symbol, get_pane_width ())
	else
		ret.upper = string.rep (md_delimiter_symbol, get_pane_width ())
		ret.lower = string.rep (md_delimiter_symbol, get_pane_width ())
	end

	return ret
end


M.get_delimiters = get_delimiters
M.output_delimiter = string.rep (output_delimiter_symbol, 3) .. 'OUTPUT' .. string.rep (output_delimiter_symbol, 3)

return M
