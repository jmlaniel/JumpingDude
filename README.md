This project consists in a plateformer game programmed in assembly for the Commodore 64.
The code needs to be compiled with the Kick Assembler compiler http://www.theweb.dk/KickAssembler/Main.html

The libraries have been developped by OldSkoolCoder for his Hunchback Twitch series except for the screen library
https://github.com/OldSkoolCoder/TwitchStreams

The physics of the player is inspired of the classic Super Mario Bros for the NES

What the player can do :
- Walk right and left horizontally
- Jumping with the fire button
- Can be controlled while jumping with different speed (forward/backward jumping)
- Waking animation
- Jumping sprite
- Have a separate sprite when the player is idle
- Limit the player from going outside the screen on left/right. I have modified the OldSkoolCoder's libSprites.asm to implement the x clamping (I have basically translated Derek Morris math macros)

Things to do next :
- Interact with the plateforms and obstacles
- Write the y clamping subroutine

Many thanks at OldSkooCoder for his devotion and enthusiam at teaching us the rudiment of Commodore 64 assmebly.
https://oldskoolcoder.co.uk/
For more information concerning Derek Morris macros : (you should buy the book!)
https://www.retrogamedev.com/

