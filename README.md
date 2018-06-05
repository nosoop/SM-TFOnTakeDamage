# SM-TFOnTakeDamage
A SourceMod plugin to hook into TF2's slightly extended OnTakeDamage function.

SDKHooks supports hooking `OnTakeDamage`.  While the `damagetype` parameter supports determining
(mini-)critical damage with `DMG_CRIT`, there is no way to manipulate the kind of crit that gets
applied with it (e.g., converting it to minicrits).

This plugin is a proof-of-concept to allow a specific type of crit to be applied, or to remove
it entirely.  It's a bit hacky, but it'll do for now.
