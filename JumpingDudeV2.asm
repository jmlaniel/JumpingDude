#import "Constants.asm"
//==============================================================================
BasicUpstart2(Start)

    * = $9000 "Start"

#import "libScreenV3.asm"
#import "libSprites.asm"
#import "libJoyStick.asm"

//==============================================================================
.const PlayerSpriteNo           = 0     // Player Sprite number = 0
.const PlayerFrameDelay         = 12    // Frame between walking sprite update
.const PlayerJumpFrameDelay     = 1     // Frame between jumping sprite update

.const jmpSt_NotJumping         = 0     // Not jumping state
.const jmpSt_StartJumping       = 1     // Start jumping cycle state
.const jmpSt_InFlight           = 2     // Inflight state

.const directionLeft            = $FF   // Left = -1
.const directionStoodStill      = 0     // Idle = 0
.const directionRight           = 1     // Right = +1

.const ForwardSpeed             = 2     // X speed for forward mouvement
.const BackwardSpeed            = 1     // X speed when backing up during jump

//==============================================================================
.label JoystickState            = $02A7 // See joystick mask in Constants.asm
.label PlayerDirection          = $02A8 // +1 = right, 255 (-1) = left, 0 = idle
.label PlayerPreviousDirection  = $02A9 // +1 = right, 255 (-1) = left
.label FrameCounter             = $02AA // Starts at 0
.label IdleDirection            = $02AB // +1 = right, 255 (-1) = left, 0 = idle
.label Jumping                  = $02AC // +1 if jumping, 0 otherwise
.label JumpIndex                = $02AD // Varies from 0 to 11 (12 states)
.label PlayerXSpeed             = $02AE // X speed value

.label PlayerXHiInit            = 0
.label PlayerXLoInit            = 24    // Initial X coordinate
.label PlayerYInit              = 221   // Initial Y coordinate

//==============================================================================
// Value to be added to y coordinate for simulating jump
JumpArk:
    .byte 232, 238, 243, 247, 251, 253, 255, 0, 0, 1, 3, 5, 9, 13, 18, 24

// Definition of sprites pointers
IdlePlayerRight:
    .byte 192
_IdlePlayerRight:

IdlePlayerLeft:
    .byte 198
_IdlePlayerLeft:

JumpPlayerRight:
    .byte 197, 197, 197, 197, 197, 197, 197, 197, 197, 197, 197, 197, 197, 197, 197, 197
_JumpPlayerRight:

JumpPlayerLeft:
    .byte 203, 203, 203, 203, 203, 203, 203, 203, 203, 203, 203, 203, 203, 203, 203, 203
_JumpPlayerLeft:

AnimatePlayerRight:
    .byte 193, 194, 195, 196
_AnimatePlayerRight:

AnimatePlayerLeft:
    .byte 199, 200, 201, 202
_AnimatePlayerLeft:

// Lengths of sprite animations
.label IdlePlayerRightLen = [_IdlePlayerRight - IdlePlayerRight]            // Number Of Bytes
.label IdlePlayerLeftLen = [_IdlePlayerLeft - IdlePlayerLeft]               // Number Of Bytes
.label JumpPlayerRightLen = [_JumpPlayerRight - JumpPlayerRight]            // Number Of Bytes
.label JumpPlayerLeftLen = [_JumpPlayerLeft - JumpPlayerLeft]               // Number Of Bytes
.label AnimatePlayerRightLen = [_AnimatePlayerRight - AnimatePlayerRight]   // Number Of Bytes
.label AnimatePlayerLeftLen = [_AnimatePlayerLeft - AnimatePlayerLeft]      // Number Of Bytes

//==============================================================================
Start:
    // Initialize Screen
    jsr libScreen.ScreenInit

    // Initialize Player Sprite
    ldy #PlayerSpriteNo
    jsr libSprites.SpriteEnable         // Enable Player sprite

    ldy #PlayerSpriteNo
    lda IdlePlayerRight
    jsr libSprites.SetFrame             // Set initial frame for Player

    ldx #PlayerXLoInit
    lda #PlayerXHiInit
    ldy #PlayerSpriteNo
    jsr libSprites.SetX                 // Set initial X coordinates

    lda #PlayerYInit
    ldy #PlayerSpriteNo
    jsr libSprites.SetY                 // Set initial Y coordinates
    
    ldy #PlayerSpriteNo 
    jsr libSprites.SpriteMultiColour    // Set Player sprite multicolor

    ldy #PlayerSpriteNo 
    jsr libSprites.SpriteColourBrown    // Set Sprite color

    lda #LIGHT_RED
    sta SPMC0                           // Set Multicolor #1

    lda #WHITE
    sta SPMC1                           // Set Multicolor #2
    
    // Setup Player animation
    lda #ForwardSpeed
    sta PlayerXSpeed                    // Set initial speed    
    lda #0
    sta FrameCounter                    // Set FrameCounter at 0
    sta JumpIndex
    lda #jmpSt_NotJumping
    sta Jumping                         // Set not jumping
    lda #directionRight
    sta PlayerPreviousDirection         // Set previous state to idle
    sta IdleDirection                   // Set idle direction right
    lda #directionStoodStill
    sta PlayerDirection                 // Set initial direction right
    SetAnimation(PlayerSpriteNo,libSprite_ACTIVE,<AnimatePlayerRight,>AnimatePlayerRight,AnimatePlayerRightLen,PlayerFrameDelay,libSprite_LOOPING,libSprite_ONDEMAND)
    jsr libSprites.UpdateSprites        // Update initial sprite

GameLooper:
    // Wait for scanline 240 (outside screen)
    lda #240
    jsr libScreen.WaitScanline

    // Increment Frame Counter
    inc FrameCounter
    lda FrameCounter
    cmp #32
    bne JumpingTest
    lda #0
    sta FrameCounter

JumpingTest:
    // Test if Jumping
    lda Jumping
    cmp #jmpSt_NotJumping
    beq ReadJoystickReg
    jsr JumpCycle

ReadJoystickReg:
    //Read and store joystick register
    jsr libJoyStick.ReadJoySticks

!TestJoystickFire:
    // Test if fire button pressed
    jsr libJoyStick.libJoy2.CheckFire
    bcc !TestJoystickRight+
    lda #jmpSt_StartJumping
    sta Jumping                     // Fire pressed, set Jumping to start

!TestJoystickRight:
    // Test if left direction is activated
    jsr libJoyStick.libJoy2.CheckRight
    bcc !TestJoystickLeft+
    lda #directionRight
    sta PlayerDirection             // Right pressed, set direction = +1
    sta IdleDirection               // Idle direction, set direction = +1
    jsr UpdatePlayer
    jmp GameLooperEnd

!TestJoystickLeft:
    // Test if left direction is activated
    jsr libJoyStick.libJoy2.CheckLeft
    bcc !TestJoystickNull+
    lda #directionLeft
    sta PlayerDirection             // Right pressed, set direction = +1
    sta IdleDirection               // Idle direction, set direction = +1
    jsr UpdatePlayer
    jmp GameLooperEnd

!TestJoystickNull:
    lda #directionStoodStill
    sta PlayerDirection             // Idle, set direction = +0
    lda PlayerPreviousDirection
    sta IdleDirection               // Save previous direction in IdleState
    jsr UpdatePlayer

//==============================================================================
GameLooperEnd:
    jsr libSprites.UpdateSprites    // Update sprites with setup states
    jmp GameLooper

//==============================================================================
UpdatePlayer:

!GoingRight:
    // Update player going right
    lda PlayerDirection
    cmp #directionRight
    bne !GoingLeft+                 // Check for right direction
    lda Jumping
    cmp #jmpSt_StartJumping         // If not jumping, keep jumping sprite
    bcs !+
    lda PlayerPreviousDirection
    cmp PlayerDirection             // Same direction, keep walking sprite
    beq !+
    SetAnimation(PlayerSpriteNo,libSprite_ACTIVE,<AnimatePlayerRight,>AnimatePlayerRight,AnimatePlayerRightLen,PlayerFrameDelay,libSprite_LOOPING,libSprite_ONDEMAND)
    lda PlayerDirection
    sta PlayerPreviousDirection     // Update previous direction
!:
    lda IdleDirection               // Test for backward jumping right
    cmp PlayerPreviousDirection
    beq !ForwardSpeed+
    lda #BackwardSpeed
    sta PlayerXSpeed                // Jumping backward, set BackwardSpeed
    jmp !SetSprite+
!ForwardSpeed:
    lda #ForwardSpeed
    sta PlayerXSpeed                // Jumping backward, set ForwardSpeed
!SetSprite:
    lda #0                          // X Hi
    ldx PlayerXSpeed                // X Lo
    ldy #PlayerSpriteNo
    jsr libSprites.AddToX           // Update Player X
    ldy #PlayerSpriteNo
    jsr libSprites.MinX             // Clamp x position

    rts

!GoingLeft:
    // Update player going left
    lda PlayerDirection
    cmp #directionLeft
    bne !GoingIdle+                 // Check for left direction
    lda Jumping
    cmp #jmpSt_StartJumping         // If not jumping, keep jumping sprite
    bcs !+
    lda PlayerPreviousDirection
    cmp PlayerDirection             // Same direction, keep walking sprite
    beq !+
    SetAnimation(PlayerSpriteNo,libSprite_ACTIVE,<AnimatePlayerLeft,>AnimatePlayerLeft,AnimatePlayerLeftLen,PlayerFrameDelay,libSprite_LOOPING,libSprite_ONDEMAND)
    lda PlayerDirection
    sta PlayerPreviousDirection     // Update previous direction
!:    
    lda IdleDirection               // Test for backward jumping right
    cmp PlayerPreviousDirection
    beq !ForwardSpeed+
    lda #BackwardSpeed
    sta PlayerXSpeed                // Jumping backward, set BackwardSpeed
    jmp !SetSprite+
!ForwardSpeed:
    lda #ForwardSpeed
    sta PlayerXSpeed                // Jumping backward, set ForwardSpeed
!SetSprite:
    lda #0                          // X Hi
    ldx PlayerXSpeed                // X Lo
    ldy #PlayerSpriteNo
    jsr libSprites.SubFromX         // Update Player X
    ldy #PlayerSpriteNo
    jsr libSprites.MaxX             // Clamp x position
    rts

!GoingIdle:
    // Update player going idle
    lda IdleDirection
    cmp #directionRight
    bne !GoingIdleLeft+             // Check for right direction
!GoingIdleRight:
    lda Jumping
    cmp #jmpSt_StartJumping         // If jumping, no change
    bcs !NoChange+
    ldy #PlayerSpriteNo
    lda IdlePlayerRight
    jsr libSprites.SetFrame         // Set sprite to idle right
!NoChange:
    rts
!GoingIdleLeft:    
    lda Jumping
    cmp #jmpSt_StartJumping         // If jumping, no change
    bcs !NoChange+
    ldy #PlayerSpriteNo
    lda IdlePlayerLeft
    jsr libSprites.SetFrame         // Set sprite to idle left
!NoChange:
    rts

//==============================================================================
JumpCycle:
    lda FrameCounter    // Frame counter goes from 0 to 32 with 16 jumping sprites
    cmp #2
    beq !+
    cmp #4
    beq !+
    cmp #6
    beq !+
    cmp #8
    beq !+
    cmp #10
    beq !+
    cmp #12
    beq !+
    cmp #14
    beq !+
    cmp #16
    beq !+
    cmp #18
    beq !+
    cmp #20
    beq !+
    cmp #22
    beq !+
    cmp #24
    beq !+
    cmp #26
    beq !+
    cmp #28
    beq !+
    cmp #30
    beq !+
    cmp #32
    beq !+

    rts

!:
    // There is 16 jumping frames (0 to 15)
    inc JumpIndex
    ldx JumpIndex
    cpx #15                             // Test for 16 jumping frames
    bne !Jump+
    jmp !EndJump+

!Jump:
    lda JumpArk,x
    tax
    lda #0                              // Y
    ldy #PlayerSpriteNo
    jsr libSprites.AddToY
    lda PlayerPreviousDirection         // Use previous Direction to set Jump direction
    cmp #directionRight
    bne !LeftAni+

!RightAni:
    lda Jumping
    cmp #jmpSt_StartJumping
    beq !SetAni+
    lda PlayerPreviousDirection
    cmp PlayerDirection
    bne !SetAni+
    jmp !JumpRet+

!SetAni:
    SetAnimation(PlayerSpriteNo,libSprite_ACTIVE,<JumpPlayerRight,>JumpPlayerRight,JumpPlayerRightLen,PlayerJumpFrameDelay,libSprite_ONCE,libSprite_CONSTANT)
    lda #jmpSt_InFlight 
    sta Jumping
    jmp !JumpRet+

!LeftAni:
    lda Jumping
    cmp #jmpSt_StartJumping
    beq !SetAni+
    lda PlayerPreviousDirection
    cmp PlayerDirection
    bne !SetAni+
    jmp !JumpRet+

!SetAni:
    SetAnimation(PlayerSpriteNo,libSprite_ACTIVE,<JumpPlayerLeft,>JumpPlayerLeft,JumpPlayerLeftLen,PlayerJumpFrameDelay,libSprite_ONCE,libSprite_CONSTANT)
    lda #jmpSt_InFlight 
    sta Jumping
    jmp !JumpRet+

!EndJump:
    // End jump by resetting JumIndex and setting the animation to walking
    lda #jmpSt_NotJumping
    sta JumpIndex
    sta Jumping
    lda IdleDirection
    cmp #directionRight
    bne !+
    SetAnimation(PlayerSpriteNo,libSprite_ACTIVE,<AnimatePlayerRight,>AnimatePlayerRight,AnimatePlayerRightLen,PlayerFrameDelay,libSprite_LOOPING,libSprite_ONDEMAND)
    jmp !JumpRet+
!:
    SetAnimation(PlayerSpriteNo,libSprite_ACTIVE,<AnimatePlayerLeft,>AnimatePlayerLeft,AnimatePlayerLeftLen,PlayerFrameDelay,libSprite_LOOPING,libSprite_ONDEMAND)

!JumpRet:
    rts 

//==============================================================================
        * = $7000 "Sprites Data"
.import binary "JumpingDude - Sprites.bin"
        * = $7800 "Character Set"
.import binary "JumpingDude - Chars.bin"
        * = $8000 "Screen Map"
.import binary "JumpingDude - Map (8bpc, 40x25).bin"
