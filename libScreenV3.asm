#import "Constants.asm"

.namespace libScreen
{
    .const VideoBank = 2        // Bank 1 at $4000
    .const ScreenMem = 16       // Screen Memory at $4000+$0400
    .const TextScreen = 68      // Pointer : (VideoBank+ScreenMem*64)/256
    .const CharacterHome = 14   // Character Memory at $4000+3800$

    .const BC = BROWN           // Border Color
    .const BCKG0 = LIGHT_BLUE   //Background color 0
    .const BCKG1 = ORANGE       //Background color 1
    .const BCKG2 = LIGHT_RED    //Background color 2
    .const BCKG3 = RED          //Background color 3

    ScreenInit:
    {
        jsr SetVideoBank
        jsr SetScreenMemory
        jsr SetCharMemory
        jsr SetColors
        jsr SetMultiColorMode
        jsr LoadCharMapMem
        lda #RED
        jsr SetColorRam

        rts
    }

    SetVideoBank:
    {
        // Set video bank
        // Ref C64 Prog Ref Guide p.102
        // Video Bank Selection - Lower 2 bits of 56576 ($DD00)
        // A = 0 (bits = 00) Bank = 3 Starting at 49152 ($C000-$FFFF) no character set
        // A = 1 (bits = 01) Bank = 2 Starting at 32768 ($8000-$BFFF)
        // A = 2 (bits = 10) Bank = 1 Starting at 16384 ($4000-$7FFF) no character set
        // A = 3 (bits = 11) Bank = 0 Starting at     0 ($0000-$3FFF) (default)
        lda C2DDRA
        ora #%00000011
        sta C2DDRA

        lda CI2PRA
        and #%11111100
        ora #VideoBank
        sta CI2PRA

        rts
    }

    SetScreenMemory:
    {
        // Set screen memory
        // Ref C64 Prog Ref Guide p.103
        // Screen Memory - Upper 4 bits of 53272 ($D018)
        // A          Bits        Location (Dec)      Location (Hex)
        //  0       0000XXXX               0             $0000
        // 16       0001XXXX            1024             $0400  (default)
        // 32       0010XXXX            2048             $0800
        // 48       0011XXXX            3072             $0C00
        // 64       0100XXXX            4096             $1000
        // 80       0101XXXX            5120             $1400
        // 96       0110XXXX            6144             $1800
        //112       0111XXXX            7168             $1C00
        //128       1000XXXX            8192             $2000
        //144       1001XXXX            9216             $2400
        //160       1010XXXX           10240             $2800
        //176       1011XXXX           11264             $2C00
        //192       1100XXXX           12288             $3000
        //208       1101XXXX           13312             $3400
        //224       1110XXXX           14336             $3800
        //240       1111XXXX           15360             $3C00
        lda VMCSB
        and #%00001111
        ora #ScreenMem
        sta VMCSB
        lda #TextScreen
        sta HIBASE

        rts
    }
    
    SetCharMemory:
    {
        // Set character memory
        // Ref C64 Prog Ref Guide p.104
        // Character Memory - Lower bits of 53272 ($D018) (bit 0 is ignored)
        // A          Bits        Location (Dec)    Location (Hex)
        //  0       XXXX000X               0         $0000-$07FF
        //  2       XXXX001X            2048         $0800-$0FFF
        //  4       XXXX010X            4096         $1000-$17FF    ROM IMAGE in Bank 0&2 (default)
        //  6       XXXX011X            6144         $1800-$1FFF    ROM IMAGE in Bank 0&2 (default)
        //  8       XXXX100X            8192         $2000-$27FF
        // 10       XXXX101X           10240         $2800-$2FFF
        // 12       XXXX110X           12288         $3000-$37FF
        // 14       XXXX111X           14336         $3800-$3FFF
        lda VMCSB
        and #%11110000
        ora #CharacterHome
        sta VMCSB

        rts
    }
    SetColors:
    {
        // BC    = Border Color       (Value)
        // BCKG0 = Background Color 0 (Value)
        // BCKG1 = Background Color 1 (Value)
        // BCKG2 = Background Color 2 (Value)
        // BCKG4 = Background Color 3 (Value)
        lda #BC         // Color0 -> A
        sta EXTCOL      // A -> EXTCOL
        lda #BCKG0      // Color1 -> A
        sta BGCOL0      // A -> BGCOL0
        lda #BCKG1      // Color2 -> A
        sta BGCOL1      // A -> BGCOL1
        lda #BCKG2      // Color3 -> A
        sta BGCOL2      // A -> BGCOL2
        lda #BCKG3      // Color4 -> A
        sta BGCOL3      // A -> BGCOL3

        rts
    }

    SetMultiColorMode:
    {
        // Set multicolor mode
        lda SCROLX
        ora #%00010000          // set bit 5
        sta SCROLX

        rts
    }

    LoadCharMapMem:
    {
        // Load screen map from memory and store in screen ram
        lda #<SCREENMAP             // Get low byte address of character map
        sta ZeroPageLow             // Store low byte in zero page ($FB)
        lda #>SCREENMAP             // Get high byte address of chararacter map
        sta ZeroPageHigh            // Store high byte in zero page ($FC)
        lda #<SCREENRAM             // Get low byte address of screen ram
        sta ZeroPageLow2            // Store low byte in zero page ($FB)
        lda #>SCREENRAM             // Get high byte address of screen ram
        sta ZeroPageHigh2           // Store high byte in zero page ($FC)

        ldx #0                      // x = Row number (0 to 25)
    !SetRowNumber:
        ldy #0                      // y = Column number (0 to 40)
    !CopyCharRow:
        lda (ZeroPageLow),y         // Load character
        sta (ZeroPageLow2),y        // Store character in screen ram
        iny
        cpy #40                     // Check end of line
        bne !CopyCharRow-

        // Add 40 to change line
        clc
        lda ZeroPageLow
        adc #40
        sta ZeroPageLow
        lda ZeroPageHigh
        adc #0
        sta ZeroPageHigh
        
        clc
        lda ZeroPageLow2
        adc #40
        sta ZeroPageLow2
        lda ZeroPageHigh2
        adc #0
        sta ZeroPageHigh2

        // Prepare next Row
        inx
        cpx #25                     // Check for end of screen
        bne !SetRowNumber-

        rts
    }

    SetColorRam:
    {
        // Set Color Ram
        // Acc = Color
        ora #00001000       // Turn on bit 3 for multicolor mode
        ldx #250            // Set loop value
    !loop:
        dex                 // X = X - 1
        sta COLORRAM,x      // Set Start + x
        sta COLORRAM+250,x  // Set Start + 250 + x
        sta COLORRAM+500,x  // Set Start + 500 + x
        sta COLORRAM+750,x  // Set Start + 750 + x
        bne !loop-

        rts
    }
    
    WaitScanline:
    {
        // Wait for scanline
        // Acc = Scanline
    !loop:
        cmp RASTER              // Compare A to current raster line
        bne !loop-              // Loop if raster line not reached 255

        rts
    }
}