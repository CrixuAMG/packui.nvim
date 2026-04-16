-- vim: fdm=marker
-- luacheck: globals vim
local M = {}
local pack_path = vim.fn.stdpath("config") .. "/pack/plugins"
local ui = require("packui.ui")
local state_path = vim.fn.stdpath("data") .. "/packui/initialized"

local current_buf = nil
local current_win = nil
local plugins = {}

function M.get_installed_plugins()
    local installed = {}
    local plugin_types = {"start", "opt"}

    for _, type in ipairs(plugin_types) do
        local type_path = pack_path .. "/" .. type
        if vim.fn.isdirectory(type_path) == 1 then
            local plugin_list = vim.fn.readdir(type_path)
            for _, name in ipairs(plugin_list) do
                local path = type_path .. "/" .. name
                if vim.fn.isdirectory(path) == 1 then
                    local repo = name
                    local git_config_path = path .. "/.git/config"
                    if vim.fn.filereadable(git_config_path) == 1 then
                        local git_config = vim.fn.readfile(git_config_path)
                        for _, line in ipairs(git_config) do
                            if line:match("^%s*url%s*=") then
                                repo = line:match("^%s*url%s*=%s*(.*)")
                                break
                            end
                        end
                    end
                    table.insert(installed, {name = name, repo = repo, type = type, path = path})
                end
            end
        end
    end
    return installed
end

function M.refresh_ui()
    if not current_buf or not vim.api.nvim_buf_is_valid(current_buf) then
        return
    end

    local lines = {}
    local highlights = {}

    table.insert(lines, "PackUI - Plugin Manager")
    table.insert(highlights, {0, -1, 0, 1, "PackUIHeader"})
    table.insert(lines, "")

    for _, plugin in ipairs(plugins) do
        local plugin_lines = ui.render_plugin(plugin)
        for _, plugin_line in ipairs(plugin_lines) do
            table.insert(lines, plugin_line.content)
            local line_num = #lines - 1
            for _, hl in ipairs(plugin_line.highlights or {}) do
                table.insert(highlights, {line_num, hl[1], line_num, hl[2], hl[3]})
            end
        end
        table.insert(lines, "")
    end

    vim.api.nvim_buf_clear_namespace(current_buf, -1, 0, -1)
    vim.api.nvim_buf_set_option(current_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(current_buf, 'modifiable', false)

    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(current_buf, -1, hl[5], hl[1], hl[2], hl[4])
    end

    if current_win and vim.api.nvim_win_is_valid(current_win) then
        local new_height = math.min(vim.o.lines - 4, #lines + 2)
        vim.api.nvim_win_set_height(current_win, new_height)
    end
end

function M.install_dependencies()
    if #plugins == 0 then
        M.write_state_file()
        return
    end

    for i, _ in ipairs(plugins) do
        plugins[i].status = "Installing"
    end
    M.refresh_ui()

    local completed = 0
    local total = #plugins

    for i, plugin in ipairs(plugins) do
        vim.system(
            {"git", "-C", plugin.path, "pull", "--ff-only"},
            {},
            function(result)
                local status = result.code == 0 and "Up to date" or "Error"
                vim.schedule(function()
                    plugins[i].status = status
                    completed = completed + 1
                    M.refresh_ui()
                    if completed == total then
                        M.write_state_file()
                    end
                end)
            end
        )
    end
end

function M.write_state_file()
    local dir = vim.fn.fnamemodify(state_path, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
    vim.fn.writefile({tostring(os.time())}, state_path)
end

function M.open()
    for _, plugin in ipairs(plugins) do
        plugin.status = nil
    end

    if current_win and vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_win_close(current_win, true)
    end

    plugins = M.get_installed_plugins()

    ui.setup_highlights()

    local buf = vim.api.nvim_create_buf(false, true)
    current_buf = buf

    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)

    local lines = {}
    local highlights = {}

    table.insert(lines, "PackUI - Plugin Manager")
    table.insert(highlights, {0, -1, 0, 1, "PackUIHeader"})
    table.insert(lines, "")

    for _, plugin in ipairs(plugins) do
        local plugin_lines = ui.render_plugin(plugin)
        for _, plugin_line in ipairs(plugin_lines) do
            table.insert(lines, plugin_line.content)
            local line_num = #lines - 1
            for _, hl in ipairs(plugin_line.highlights or {}) do
                table.insert(highlights, {line_num, hl[1], line_num, hl[2], hl[3]})
            end
        end
        table.insert(lines, "")
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(buf, -1, hl[5], hl[1], hl[2], hl[4])
    end

    local width = math.min(vim.o.columns - 4, 100)
    local height = math.min(vim.o.lines - 4, #lines + 2)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = col,
        row = row,
        style = 'minimal',
        border = 'rounded',
    })
    current_win = win

    local function set_win_options(w)
        vim.api.nvim_win_set_option(w, 'wrap', false)
        vim.api.nvim_win_set_option(w, 'cursorline', true)
        vim.api.nvim_win_set_option(w, 'number', false)
        vim.api.nvim_win_set_option(w, 'relativenumber', false)
    end
    set_win_options(win)

    vim.api.nvim_buf_set_option(buf, 'buflisted', false)

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<cr>', {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>close<cr>', {noremap = true, silent = true})

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        callback = function()
            current_win = nil
            current_buf = nil
        end,
        once = true,
    })
end

function M.setup()
    vim.api.nvim_create_user_command("PackUI", function() M.open() end, {force = true})

    if vim.fn.filereadable(state_path) == 0 then
        local first_run_callback = function()
            M.open()
            vim.schedule(function()
                M.install_dependencies()
            end)
        end

        if vim.v.vim_did_enter == 1 then
            first_run_callback()
        else
            vim.api.nvim_create_autocmd("VimEnter", {
                callback = first_run_callback,
                once = true,
            })
        end
    end
end

return M