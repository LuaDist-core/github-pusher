# Github Pusher

A LuaDist utility used to push package repositories

## Configuration

Github Pusher can be configured by specifying several environment variables described below.


- `PUSHER_REPO_PATH` - the directory with repositories to push (defaults to `data/repos`)
- `PUSHER_LOG_DIR` - directory to keep the logs in (defaults to `logs`))
- `PUSHER_ORG_NAME` - the name of the Github organization where the repositories should go (defaults to `LuaDist2`; you should set either this or `PUSHER_USER_NAME`, but not both)
- `PUSHER_USER_NAME` - the name of the Github user where the repositories should go (defaults to an empty string; you should set either this or `PUSHER_ORG_NAME`, but not both)
- `PUSHER_GITHUB_TOKEN` - Github access token allowing to create repositories on the given account (no default, must be set)
- `PUSHER_TRAVIS_TOKEN` - Travis access token for the given account (no default, must be set)
- `PUSHER_TRAVIS_SYNC_WAIT` - how long should the pusher wait for Travis to synchronize with the Github account (defaults to `30`)

