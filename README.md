# TF2 OnTakeDamage Hooks
A SourceMod plugin to hook into TF2's slightly extended OnTakeDamage functions.

SDKHooks supports hooking `OnTakeDamage`.  While the `damagetype` parameter supports determining
the existence of critical-like damage with `DMG_CRIT`, there is no way to differentiate nor
manipulate the particular crit type that is applied.

This plugin is a proof-of-concept to allow a specific type of crit to be applied, or to remove
it entirely.  It's a bit hacky, but it'll do for now.
