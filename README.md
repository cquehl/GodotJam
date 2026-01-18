# GodotJam
TODO:

[ ] the #1 todo is loading on the Itch.Io site on HTML through its features or whatever... super lag when clicking contineu -- and super lag during the firsdt 5 seconds of play.. just load it - they are going to click space bar.
 
[ ] Smooth against hte wall - dont get "stuck" for pushing the boundary

All "blue" raindrop orbs now have this type of texture -- https://godotshaders.com/shader/fireball-or-candle-fire-shader/
add 7 layers of obfuscation so it is a legally different design

all "green" point orbs need to have a yellow and white lighting circle: https://godotshaders.com/shader/electric-ball-canvas-item/




DID:
[X] Add shadows to the rain drops
rain drops should spawn further out closer to edge of rendering
[X] Add instructions to title screen
[X] once you collect 5 green points - introduce a larger rain drop that is "fired towards" the flames current position.
[X] once you collect 7 green points, now the larger rain drops are fired in an array with one second apart. rnd 3 or 5.
N/A. figure out what to do w/ jumping mechanic, maybe thers a long roller that crosses the entire of the disc that must be jumped over maybe once every minute and then increases with each point until its once every 10 seconds?

Done: export as html to itch.io -- I read C# in godot might not support web export ...
itch site markdown for MiniJam #50
Credit https://godotshaders.com/shader/stylized-botw-fire/ for the fire animation

----
update score UI - can't see it
[X] when clicking spacebar to start, let the user know game is loading imedieatly then load the game (takes about 7 seconds to load they need instant feedback)
[X] figure out loading, maybe pre load?

[X] get a giant barrage if you hit 20? or maybe randomly? one too big to jump over
[X] Show the score and High Score on the game over
friction/sticky against edge - want to be smooth