local M = {}

M.icons = {
    update = "󰚰 ",
    uptodate = " ",
    checking = "󱑎 ",
    error = " ",
    type_start = "󱐌 ",
    type_opt = "󱓞 ",
    arrow = "➜ ",
}

M.highlights = {
    PackUIHeader = { fg = "#89b4fa", bold = true },
    PackUIPluginName = { fg = "#cdd6f4", bold = true },
    PackUIStatusUpdate = { fg = "#fab387" },
    PackUIStatusOk = { fg = "#a6e3a1" },
    PackUIStatusChecking = { fg = "#94e2d5" },
    PackUIChangelog = { fg = "#7f849c", italic = true },
    PackUIType = { fg = "#f5c2e7" },
}

function M.setup_highlights()
    for name, opts in pairs(M.highlights) do
        vim.api.nvim_set_hl(0, name, opts)
    end
end

function M.render_plugin(p)
    local icon = M.icons.checking
    local status_hl = "PackUIStatusChecking"
    
    if p.status == "Update Available" then
        icon = M.icons.update
        status_hl = "PackUIStatusUpdate"
    elseif p.status == "Up to date" then
        icon = M.icons.uptodate
        status_hl = "PackUIStatusOk"
    elseif p.status == "Error" or p.status == "Fetch Failed" then
        icon = M.icons.error
        status_hl = "DiagnosticError"
    end

    local type_icon = p.type == "start" and M.icons.type_start or M.icons.type_opt
    
    local lines = {}
    -- Header line with virtual text for status
    table.insert(lines, {
        content = string.format(" %s %-22s %s %s", icon, p.name, type_icon, p.repo),
        highlights = {
            {0, 3, status_hl},
            {4, 4 + #p.name, "PackUIPluginName"},
            {27, 27 + #type_icon, "PackUIType"},
        }
    })

    if #p.changelog > 0 then
        for _, log in ipairs(p.changelog) do
            table.insert(lines, {
                content = "    " .. M.icons.arrow .. log,
                highlights = { {4, -1, "PackUIChangelog"} }
            })
        end
    end
    
    return lines
end

return M
