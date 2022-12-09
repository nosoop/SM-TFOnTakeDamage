# TF2 OnTakeDamage Hooks
A SourceMod plugin to hook into TF2's slightly extended OnTakeDamage functions.

SDKHooks supports hooking `OnTakeDamage`.  While the `damagetype` parameter supports determining
the existence of critical-like damage with `DMG_CRIT`, there is no way to differentiate nor
manipulate the particular crit type that is applied.

This plugin is a proof-of-concept to allow a specific type of crit to be applied, or to remove
it entirely.  It's a bit hacky, but it'll do for now.

## Building

This project is configured for building via [Ninja][]; see `BUILD.md` for detailed
instructions on how to build it.

If you'd like to use the build system for your own projects,
[the template is available here](https://github.com/nosoop/NinjaBuild-SMPlugin).

For this particular project, you will also need the chevron and dissect packages.  You can
install those using `pip install -r build-py-requirements.txt`.  Further build-specific details
are located at the end of `BUILD.md`.

[Ninja]: https://ninja-build.org/
