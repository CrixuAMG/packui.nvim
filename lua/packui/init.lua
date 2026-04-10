-- vim: fdm=marker
-- luacheck: globals vim
local M = {}
local pack_path = vim.fn.stdpath("config") .. "/pack/plugins"
local ui = require("packui.ui")

function M.get_installed_plugins()
    local installed = {}
    local plugin_types = {"start", "opt"}

    for _, type in ipairs(plugin_types) do
        local type_path = pack_path .. "/" .. type
        if vim.fn.isdirectory(type_path) == 1 then
            local plugins = vim.fn.readdir(type_path)
            for _, name in ipairs(plugins) do
                local path = type_path .. "/" .. name
                if vim.fn.isdirectory(path) == 1 then
                    -- Try to get the repo from the plugin's git config
                    local repo = name  -- fallback to directory name
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

function M.open()
    -- Get installed plugins
    local plugins = M.get_installed_plugins()
    
    -- Set up highlights
    ui.setup_highlights()
    
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    
    -- Set window options when we create the window
    local function set_win_options(win)
        vim.api.nvim_win_set_option(win, 'wrap', false)
        vim.api.nvim_win_set_option(win, 'cursorline', true)
        vim.api.nvim_win_set_option(win, 'number', false)
        vim.api.nvim_win_set_option(win, 'relativenumber', false)
    end
    
    -- Prepare content
    local lines = {}
    local highlights = {}
    
    -- Add header
    table.insert(lines, "PackUI - Plugin Manager")
    table.insert(highlights, {0, -1, 0, 1, "PackUIHeader"})
    table.insert(lines, "")
    
    -- Add plugin list
    for _, plugin in ipairs(plugins) do
        local plugin_lines = ui.render_plugin(plugin)
        for _, plugin_line in ipairs(plugin_lines) do
            table.insert(lines, plugin_line.content)
            -- Add highlights for this line
            local line_num = #lines - 1
            for _, hl in ipairs(plugin_line.highlights or {}) do
                table.insert(highlights, {line_num, hl[1], line_num, hl[2], hl[3]})
            end
        end
        table.insert(lines, "") -- Empty line between plugins
    end
    
    -- Set buffer content
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Apply highlights
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(buf, -1, hl[5], hl[1], hl[2], hl[4])
    end
    
    -- Open window
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
    
    set_win_options(win)
    
    -- Set buffer as unlisted
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
end

function M.setup()
    vim.api.nvim_create_user_command("PackUI", function() M.open() end, {})
end

return M
