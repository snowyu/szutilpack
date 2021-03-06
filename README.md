A collection of miscellaneous mods for minetest providing "utility" functonality: management features, bug workarounds, and libraries for other mods.  Each mod includes an individual README file with details on its use.

Each mod in the pack is effectively independent, with minimal or no dependencies (including on any assumed underlying game) and they can be enabled/disabled individually.  Mods are distributed as a single pack because they have a single shared maintenance/release cycle.

- `szutil_admin`: Alternative to the "admin" command that lists moderation team members.
- `szutil_chatsocket`: Expose in-game chat stream as a unix-domain socket for arbitrary chat integrations.
- `szutil_chatsounds`: Configurable beep notifications for in-game chat.
- `szutil_clocksync`: Synchronize in-game clock smoothly with real-time clock so users can log in at predictable times of day.
- `szutil_consocket`: Expose an admin console as a unix-domain socket for clientless admin via ssh.
- `szutil_controlhud`: Togglable on-screen input control HUD, useful for demo recording.
- `szutil_fixhack`: Fix lighting and fluid bugs automatically and continuously in background.
- `szutil_givemenu`: Menu-driven searchable version of the /give command.
- `szutil_lagometer`: Optional on-screen server performance meter HUD.
- `szutil_logtrace`: Allow privileged players to monitor server debug trace in chat.
- `szutil_maplimitfx`: Display particle visual at hard map boundaries.
- `szutil_motd`: Display a formspec MOTD to players on login, only if updated since the last view.
- `szutil_nowonline`: Periodically display cumulative list of online players, for chat bridges.
- `szutil_nukeplayer`: Adds a /nuke_player command to completely destroy a player account.
- `szutil_revokeme`: Fixes missing /revokeme admin command.
- `szutil_roles`: Manage privs via special privs that represent groups of other privs.
- `szutil_restart`: Externally-triggerable server restarts with countdown/warnings.
- `szutil_stealth`: Make a player as close to completely invisble to players as possible, for moderation or spectation use.
- `szutil_suadmin`: Change admin access to be based on a /su (password) command, instead of by player name.
- `szutil_telecode`: Teleportation by opaque codes that can be shared, saved, and published.
- `szutil_usagesurvey`: Collect usage statistics per-mapblock on how each is being used (e.g. for pruning lightly-used portions of the map).
- `szutil_watch`: Allow privileged players to attach to and spectate other players.