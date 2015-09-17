Pico-8 javascript runtime
=========================

This is my quick and dirty reimplementation of the Pico-8 fantasy console

Known issues
------------
* Cannot handle game loops that don't rely on _update / _draw loops (recompiler non-reenterant)
* Numerous functions have not been implemented
* Virtual filesystem has not been implemented, and there is no way to inject programs into platform
* Audio mixer doesn't have effects, is poorly tuned and is generally broken
