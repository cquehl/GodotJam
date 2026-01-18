# FIREBALL - GodotJam

A dodge-and-collect arcade game built with Godot 4.5. Control a flaming orb on a circular platform, avoid water droplets, and collect points.

## TODO

- [ ] Optimize HTML5 export for itch.io (reduce lag on initial load and first 5 seconds of play)
- [ ] Smooth wall collision (prevent "sticking" to platform edge)
- [ ] Add fire shader obfuscation layers (legal differentiation from reference)

## Completed

- [X] Add shadows to rain drops
- [X] Add instructions to title screen
- [X] Larger rain drops fired at player position at 5+ points
- [X] Multi-barrage system (1+ second apart) at 7+ points
- [X] Export as HTML5 to itch.io
- [X] Loading feedback ("Starting..." animation)
- [X] Resource preloading system
- [X] Mega droplets at score 20+
- [X] High score display on game over
- [X] Glowing platform rim indicator

## Code Review Notes

### Architecture

**Strengths:**
- Object pooling (`droplet_pool.gd`) for efficient droplet management
- Signal-based architecture keeps systems decoupled
- Resource preloading prevents stutters on scene transitions
- Audio management with SFX pool and crossfading

**Areas for improvement:**
- Consider consolidating `Preloader` and `DropletPool` autoloads

### Performance Notes

- Object pooling, shader caching, and threaded resource loading are well-implemented
- `Time.get_ticks_msec()` called every frame in droplet bobbing - acceptable but could use delta accumulation
- Material references could be cached in `_update_powerup_visuals()`

## Credits

- Fire animation shader: https://godotshaders.com/shader/stylized-botw-fire/
- Electric ball shader: https://godotshaders.com/shader/electric-ball-canvas-item/
- Menu music: CC Zero / Public Domain by iamoneabe - https://allmylinks.com/iamoneabe
