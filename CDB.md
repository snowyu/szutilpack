A pack of independent utilities, including:

- `szutil_chatsocket`: Expose in-game chat stream as a unix-domain socket for arbitrary chat integrations.
- `szutil_clocksync`: Synchronize in-game clock smoothly with real-time clock so users can log in at predictable times of day.
- `szutil_consocket`: Expose an admin console as a unix-domain socket for clientless admin via ssh.
- `szutil_controlhud`: Togglable on-screen input control HUD, useful for demo recording.
- `szutil_fixhack`: Fix lighting and fluid bugs automatically and continuously in background.
- `szutil_invite`: Let players invite other players to teleport to visit them, but they can't bring items this way.
- `szutil_lagometer`: Optional on-screen server performance meter HUD.
- `szutil_limitworld`: Limit mapgen to a floating hemisphere, with players taking damage if they fall off.
- `szutil_logtrace`: Allow privileged players to monitor server debug trace in chat.
- `szutil_motd`: Display a formspec MOTD to players on login, only if updated since the last view.
- `szutil_roles`: Manage privs via special privs that represent groups of other privs.
- `szutil_spiralhomes`: New players are assigned initial spawn locations dispersed around the world in an outward spiral.
- `szutil_suadmin`: Change admin access to be based on a /su (password) command, instead of by player name.
- `szutil_usagesurvey`: Collect usage statistics per-mapblock on how each is being used (e.g. for pruning lightly-used portions of the map).
- `szutil_watch`: Allow privileged players to spectate other players.

Each mod in the pack is effectively independent, and they can be enabled/disabled individually.  Mods are distributed as a single pack because they have a single shared maintenance/release cycle.