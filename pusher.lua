module("pusher", package.seeall)

local pl = {}
pl.dir = require 'pl.dir'
pl.path = require 'pl.path'
pl.utils = require 'pl.utils'

local cfg = require 'pusher.config'
local util = require 'pusher.util'

local logging = require "logging"
require "logging.file"

local log = logging.file(cfg.logDir .. "/pusher-%s.log", "%Y-%m-%d")
--log:setLevel(logging.ERROR)

-- Iterate over all repositories
local repos = pl.dir.getdirectories(cfg.repoPath)

for _, repo in pairs(repos) do
  repeat
    -- Assume that name of folder with repository is identical to module name
    local modName = pl.path.relpath(repo, cfg.repoPath)

    -- Prevent shell command injection, alternative modName = modName:gsub('\'', '\\\'') ?
    if modName:find('\'') then
      log:error('Module "' .. modName '" contains invalid character(s), skipping')
      break
    end

    log:debug('Working on path "' .. repo .. '", modName "' .. modName .. '"')

    -- If repository has remote set, it means that also github repository is created and vice versa
    local err, remotes = util.git_command(repo, 'remote')
    if err then
      break
    end

    -- We need to create github repository and add remote
    if not remotes:find('origin') then
      --log:debug('Found new repository "' .. repo .. '", initializing')

      local cmd = 'curl -d \'{"name": "' .. modName .. '"}\' -u "' .. cfg.authString .. '" https://api.github.com/' .. cfg.apiUrl

      local ok, _, stdout, stderr = pl.utils.executeex(cmd)
      if not ok then
        log:error('Failed to create github repository for module "' .. modName .. '"\nCurl stdout: ' .. stdout .. "\nCurl stderr: " .. stderr)
        break
      end

      local err, stdout, stderr = util.git_command(repo, 'remote add origin \'https://' .. cfg.authString .. '@github.com/' .. cfg.githubDir .. '/' .. modName .. '.git\'')
      if err then
        log:error("Error while adding remote.\nStdout:\n" .. stdout .. "\n\nStderr:\n" .. stderr)
        break
      end
    end

    local err, stdout, stderr = util.git_command(repo, 'remote -v')
    if err then
      log:error("Error running git remote -v.\nStdout:\n" .. stdout .. "\n\nStderr:\n" .. stderr)
      break
    end

    log:debug("Remote: " .. stdout)

    local err, stdout, stderr = util.git_command(repo, 'push origin --all --force')
    if err then
      log:error("Error while pushing to origin.\nStdout:\n" .. stdout .. "\n\nStderr:\n" .. stderr)
      break
    end
    local err, stdout, stderr = util.git_command(repo, 'push origin --tags --force')
    if err then
      log:error("Error while pushing tags to origin.\nStdout:\n" .. stdout .. "\n\nStderr:\n" .. stderr)
      break
    end
  until true
end

--[[

- authString - saving it in remote is bad idea, it breaks on change

--]]
