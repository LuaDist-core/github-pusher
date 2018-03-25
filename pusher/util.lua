module("pusher.util", package.seeall)

local pl = {}
pl.utils = require 'pl.utils'

function git_command(repo, cmd)
    -- -C <path>
    -- Run as if git was started in <path> instead of the current working directory.
    cmd = 'git -C ' .. repo .. ' ' .. cmd
    local ok, _, stdout, stderr = pl.utils.executeex(cmd)

    if not ok or stdout:find('fatal: ') or stderr:find('fatal: ') then
      return true, stdout, stderr
    end

    return false, stdout, stderr
end
