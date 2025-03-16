local M = {}

M.opts = {
	ft = "",
}

local function log(msg, level)
	level = level or vim.log.levels.ERROR
	vim.notify("[JSONEmbed] " .. msg, level)
end

local function decode_json(json_str)
	local ok, result = pcall(vim.fn.json_decode, json_str)
	if not ok then
		log("Failed to decode JSON: " .. result)
		return nil
	end
	return result
end

local function encode_json(data)
	local ok, result = pcall(vim.fn.json_encode, data)
	if not ok then
		log("Failed to encode JSON: " .. result)
		return nil
	end
	return result
end

local function set_buffer_content(buf, content, filetype)
	vim.api.nvim_buf_set_option(buf, "filetype", filetype)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
end

local function create_scratch_buffer(name, content, filetype)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "buflisted", true)
	vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	vim.api.nvim_buf_set_name(buf, name)

	set_buffer_content(buf, content, filetype)
	return buf
end

local function switch_to_scratch_buffer(buf, content, filetype)
	local window_num = vim.fn.bufwinnr(buf)
	if window_num ~= -1 then
		vim.cmd(window_num .. "wincmd w")
	else
		vim.cmd("vsplit +buffer " .. buf)
	end
	set_buffer_content(buf, content, filetype)
end

local function create_or_open_buffer(name, content, filetype)
	local existing = vim.fn.bufnr(name)
	if existing ~= -1 then
		switch_to_scratch_buffer(existing, content, filetype)
		return existing
	else
		local buf = create_scratch_buffer(name, content, filetype)
		vim.cmd("vsplit +buffer" .. buf)
		return buf
	end
end

local function extract_json_at_cursor()
	if not pcall(require, "nvim-treesitter") then
		log("nvim-treesitter is not available")
		return nil
	end

	local ts = require("nvim-treesitter.ts_utils")
	local node = ts.get_node_at_cursor()

	if node and node:type() == "string_content" or node:type() == "escape_sequence" then
		node = node:parent()
	end

	if node and node:type() == "string" and node:parent() and node:parent():type() == "pair" then
		node = node:parent()
	end

	if node and node:type() == "pair" then
		node = node:named_child(1)
	end

	if not node or node:type() ~= "string" then
		log("No string found at cursor")
		return nil
	end

	local text = vim.treesitter.get_node_text(node, 0)
	return text, node
end

local function get_scratch_buffer_name(node)
	local current_buf = vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(current_buf)
	local row, col = node:range()

	return string.format("%s:%d:%d", name, row + 1, col)
end

function M.edit_embedded()
	local original_buf = vim.api.nvim_get_current_buf()

	if not vim.api.nvim_get_option_value("filetype", { buf = original_buf }) == "json" then
		log("Only supported for JSON files")
		return nil
	end

	local json_str, node = extract_json_at_cursor()
	if not json_str or not node then
		return
	end

	local decoded = decode_json(json_str)
	if not decoded then
		return
	end

	local name = get_scratch_buffer_name(node)
	local scratch_buf = create_or_open_buffer(name, decoded, M.opts.ft)

	local start_row, start_col, end_row, end_col = node:range()

	local augroup = vim.api.nvim_create_augroup("JSONEmbedScratchBuffer", { clear = false })
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		group = augroup,
		buffer = scratch_buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(scratch_buf, 0, -1, false)

			for i, line in ipairs(lines) do
				lines[i] = vim.trim(line)
			end

			local content = encode_json(table.concat(lines, " "))
			if not content then
				return
			end

			vim.api.nvim_buf_set_text(original_buf, start_row, start_col, end_row, end_col, { content })
			end_row = start_row
			end_col = start_col + #content
		end,
	})

	vim.api.nvim_create_autocmd("BufModifiedSet", {
		group = augroup,
		buffer = scratch_buf,
		callback = function()
			vim.api.nvim_buf_set_option(scratch_buf, "modified", false)
		end,
	})
end

M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_extend("force", M.opts, opts)

	vim.api.nvim_create_user_command("JSONEmbedEdit", M.edit_embedded, {})
	--
	-- vim.keymap.set("n", "<leader>x", function()
	-- 	vim.cmd("source %")
	-- 	require("lazy.core.loader").reload("json-embed")
	-- end, { noremap = true })
end

return M
