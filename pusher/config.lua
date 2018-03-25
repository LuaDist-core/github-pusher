module ("pusher.config", package.seeall)

local path = require "pl.path"

--[[
	When changing authString, orgName or userName, it is recommended to run
	"lua forAll.lua remote rm origin"
	to refresh remotes for repositories
--]]

-- Full path to directory containing git repositories to push to Github
repoPath = os.getenv("PUSHER_REPO_PATH") or path.abspath('data/repos')
logDir   = os.getenv("PUSHER_LOG_DIR") or path.abspath('logs')

-- Specifies user or organization for which repositories should be created, one of them should be nil or ''
orgName  = os.getenv("PUSHER_ORG_NAME") or 'LuaDist2'
userName = os.getenv("PUSHER_USER_NAME") or ''

githubToken = os.getenv("PUSHER_GITHUB_TOKEN") or error("environment variable PUSHER_GITHUB_TOKEN must be set")
travisToken = os.getenv("PUSHER_TRAVIS_TOKEN") or error("environment variable PUSHER_TRAVIS_TOKEN must be set")

-- The time (in seconds) we'll wait for Travis to sync before trying to activate the repositories again
travisSyncWait = tonumber(os.getenv("PUSHER_TRAVIS_SYNC_WAIT")) or 30
-- TODO: travis max tries?

---------------------------------------
-- Config post processing - DO NOT EDIT
apiUrl = ''
githubDir = ''
if orgName and orgName ~= '' then
	apiUrl = 'orgs/' .. orgName .. '/repos'
	githubDir = orgName
elseif userName and userName ~= '' then
	apiUrl = 'user/repos'
	githubDir = userName
else
	error('Config: Please specifiy orgName or userName to use this tool')
end

-- Authentification string in form user:password
-- Github access token can be used instead of password
authString = githubDir .. ':' .. githubToken

