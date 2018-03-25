local pl = {}
pl.dir = require 'pl.dir'

local util = require 'pusher.util'

local cfg = require 'pusher.config'
local log_console = require 'logging.console'

local log = log_console()

if #arg < 2 then
	log:error('Usage: ' .. arg[0] .. ' <command>')
	log:error('Executes <command> for each repository in github uploader repository folder')
	log:error('For example, "remote rm origin" or "gc --prune=now --aggressive"')
end

-- Form a single command from all command line arguments
local command = ''

for i = 1, #arg do
	command = command .. ' ' .. arg[i]
end

log:info('Running command "' .. command .. '"')

-- Iterate over all repositories
local repos = pl.dir.getdirectories(cfg.repoPath)

for _, repo in pairs(repos) do
    util.git_command(repo, command)
end
