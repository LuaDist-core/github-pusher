module("pusher", package.seeall)

local pl = {}
pl.dir = require 'pl.dir'
pl.path = require 'pl.path'
pl.utils = require 'pl.utils'
pl.pretty = require 'pl.pretty'

local cfg = require 'pusher.config'
local util = require 'pusher.util'

local logging = require "logging"
require "logging.file"

local json = require 'json'

local log = logging.file(cfg.logDir .. "/pusher-%s.log", "%Y-%m-%d")

--log:setLevel(logging.ERROR)

-- Iterate over all repositories
local repos = pl.dir.getdirectories(cfg.repoPath)
local travisRepos = {}

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

      -- we probably need to wire Travis with this repo, save it for later
      table.insert(travisRepos, repo)

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


-- Connect with Travis CI

local function sleep(seconds)
  os.execute("sleep " .. seconds)
end

local function urlencode(str)
  str = string.gsub(str, "\r?\n", "\r\n")

  str = string.gsub(str, "([^%w%-%.%_%~ ])", function (c)
    return string.format("%%%02X", string.byte(c))
  end)

  str = string.gsub (str, " ", "+")

  return str
end

local function travisRequest(method, endpoint, data)
  local cmd = 'curl -X ' .. method .. ' ' ..
              '-H "Content-Type: application/json" ' ..
              '-H "Travis-API-Version: 3" ' ..
              '-H "User-Agent: LunaCI" ' ..
              '-H "Authorization: token ' .. cfg.travisToken .. '" '

  if data then
    cmd = cmd .. '-d \'' .. data .. '\' '
  end

  cmd = cmd .. 'https://api.travis-ci.org/' .. endpoint

  local ok, _, stdout, stderr = pl.utils.executeex(cmd)
  if not ok then
    return ok, nil, cmd
  end

  local data = json.decode(stdout)
  return data["@type"] ~= "error", data, cmd
end

local function travisActivateRepo(repo)
  return travisRequest("POST", "repo/" .. urlencode(repo) .. "/activate")
end

local function travisRequestBuild(repo)
  return travisRequest("POST", "repo/" .. urlencode(repo) .. "/requests")
end

local function travisSetEnv(repo)
  return travisRequest(
    "POST",
    "repo/" .. urlencode(repo) .. "/env_vars",
    '{ "env_var.name": "GITHUB_ACCESS_TOKEN", "env_var.value": "' .. cfg.githubToken .. '", "env_var.public": false }'
  )
end

local function travisSync()
  local ok, data, cmd = travisRequest("GET", "user")
  if not ok then
    return ok, data, cmd
  end

  local user_id = data['id']

  return travisRequest("POST", "user/" .. user_id .. "/sync")
end

local function travisWireRepository(repo)
  -- Assume that name of folder with repository is identical to module name
  local modName = pl.path.relpath(repo, cfg.repoPath)

  log:debug("Enabling Travis for '" .. modName .. "'")

  local ok, data = travisSetEnv(cfg.githubDir .. "/" .. modName)
  --log:debug("Env:\nData: " .. pl.pretty.write(data))
  if not ok then
    log:error("Error setting environment variables on Travis-CI.\nData: " .. pl.pretty.write(data))
    return false
  end

  local ok, data = travisActivateRepo(cfg.githubDir .. "/" .. modName)
  --log:debug("Activate:\nData: " .. pl.pretty.write(data))
  if not ok then
    log:error("Error trying to activate repository on Travis-CI.\nData: " .. pl.pretty.write(data))
    return false
  end

  local ok, data = travisRequestBuild(cfg.githubDir .. "/" .. modName)
  --log:debug("Request:\nData: " .. pl.pretty.write(data))
  if not ok then
    log:error("Error requesting Travis-CI build.\nData: " .. pl.pretty.write(data))
    return false
  end

  return true
end

log:debug("Syncing Travis account...")
local ok, data = travisSync()
if not ok then
  log:error("Error syncing Travis account.\nData: " .. pl.pretty.write(data))
  os.exit(1)
end

log:debug("Waiting for " .. cfg.travisSyncWait .. " seconds...")
sleep(cfg.travisSyncWait)

local stillInactive = travisRepos

while #stillInactive > 0 do
  travisRepos = stillInactive
  stillInactive = {}

  for _, repo in pairs(travisRepos) do
    if not travisWireRepository(repo) then
      table.insert(stillInactive, repo)
    end
  end

  if #stillInactive > 0 then
    log:debug("There are still some inactive Travis repos, waiting for " .. cfg.travisSyncWait .. " seconds before trying again...")
    sleep(cfg.travisSyncWait)
  end
end

--[[

- authString - saving it in remote is bad idea, it breaks on change

--]]