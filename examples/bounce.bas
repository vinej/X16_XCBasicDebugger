' =====================================================================
' bounce.bas -- x16_library bounce demo, XBasic edition (module version)
' =====================================================================
' A frame-locked green sprite bounces around the 640x480 display on 8.8
' fixed-point velocity, plays a PSG blip on every wall hit and a YM2151
' FM note while it overlaps a target box. Press any key to quit.
'
' The graphics/sound come from the x16_library, now bundled INTO the
' XBasic fork: just INCLUDE the module you need (x16sprite, x16psg, ...)
' and the library code links itself in. The physics and collision are
' plain XBasic -- breakpoint the move code and watch posx/velx.
'
' Run windowed: it needs real VSYNC.
' =====================================================================

INCLUDE "x16const.bas"
INCLUDE "x16screen.bas"
INCLUDE "x16palette.bas"
INCLUDE "x16tile.bas"
INCLUDE "x16sprite.bas"
INCLUDE "x16vera.bas"
INCLUDE "x16irq.bas"
INCLUDE "x16input.bas"
INCLUDE "x16psg.bas"
INCLUDE "x16ym.bas"

CONST PLAYW  = 640
CONST PLAYH  = 480
CONST SPR    = 16
CONST BOXX   = 304
CONST BOXY   = 200
CONST BOXW   = 80
CONST BOXH   = 80
CONST BLIPFR = 15
CONST BCOL   = 38
CONST BROW   = 25
CONST BCOLS  = 10
CONST BROWS  = 10

' position is 24-bit fixed point: low byte = fraction, high 16 = pixel.
DIM posx AS LONG
DIM posy AS LONG
DIM velx AS INT
DIM vely AS INT
DIM px AS WORD
DIM py AS WORD
DIM hit AS BYTE
DIM hitprev AS BYTE
DIM blip AS BYTE
DIM col AS BYTE
DIM row AS BYTE
DIM k AS BYTE
DIM ok AS BYTE
' wall bounds in 8.8 fixed point, computed in LONG steps (a 16-bit
' constant fold of (PLAYW-SPR-1)*256 = 159488 would overflow).
DIM xmax AS LONG
DIM ymax AS LONG

' retrigger the bounce blip
SUB startblip () STATIC
    CALL x16_psg_set_freq(0, 2362)
    CALL x16_psg_set_wave(0, X16_PSG_WAVE_PULSE, 32)
    blip = BLIPFR
END SUB

' ---- setup ----------------------------------------------------------
CALL x16_screen_cls()

FOR col = BCOL TO BCOL + BCOLS - 1
    CALL x16_tile_put(col, BROW, $A0, $0E)
    CALL x16_tile_put(col, BROW + BROWS - 1, $A0, $0E)
NEXT col
FOR row = BROW TO BROW + BROWS - 1
    CALL x16_tile_put(BCOL, row, $A0, $0E)
    CALL x16_tile_put(BCOL + BCOLS - 1, row, $A0, $0E)
NEXT row

CALL x16_sprite_init_all()
' paint a 16x16 block of palette index 2 into the sprite image at $13000
CALL x16_vera_set_addr0($00, $30, $11)
CALL x16_vera_fill(2, 256)
CALL x16_pal_set(2, $F0, $00)                ' bright green
CALL x16_sprite_image(0, $13000, X16_SPRITE_MODE_8BPP)
CALL x16_sprite_size(0, X16_SPRITE_SIZE_16, X16_SPRITE_SIZE_16, 0)
CALL x16_sprite_z(0, X16_SPRITE_Z_FRONT)
CALL x16_sprites_on()

CALL x16_psg_init()
ok = x16_ym_init()
ok = x16_ym_patch(0, 1)
CALL x16_ym_vol(0, 0)
CALL x16_ym_pan(0, 3)

CALL x16_irq_install()

posx = 64 * 256
posy = 48 * 256
velx = 384
vely = 192
hitprev = 0
blip = 0
xmax = PLAYW - SPR - 1
xmax = xmax * 256
ymax = PLAYH - SPR - 1
ymax = ymax * 256

' ---- main loop ------------------------------------------------------
DO
    CALL x16_vsync_wait()

    posx = posx + velx
    IF posx < 0 THEN
        posx = 0
        velx = 0 - velx
        CALL startblip()
    END IF
    IF posx > xmax THEN
        posx = xmax
        velx = 0 - velx
        CALL startblip()
    END IF

    posy = posy + vely
    IF posy < 0 THEN
        posy = 0
        vely = 0 - vely
        CALL startblip()
    END IF
    IF posy > ymax THEN
        posy = ymax
        vely = 0 - vely
        CALL startblip()
    END IF

    px = posx / 256
    py = posy / 256
    CALL x16_sprite_pos(0, px, py)

    ' AABB collision against the box
    hit = 0
    IF px < BOXX + BOXW THEN
        IF px + SPR > BOXX THEN
            IF py < BOXY + BOXH THEN
                IF py + SPR > BOXY THEN
                    hit = 1
                END IF
            END IF
        END IF
    END IF

    ' FM note on the collision edge only
    IF hit <> hitprev THEN
        IF hit = 1 THEN
            CALL x16_ym_note_bas(0, $44)
        ELSE
            CALL x16_ym_release_note(0)
        END IF
        hitprev = hit
    END IF

    ' PSG blip volume envelope
    IF blip > 0 THEN
        blip = blip - 1
        CALL x16_psg_set_vol(0, blip * 4, X16_PSG_PAN_BOTH)
    ELSE
        CALL x16_psg_set_vol(0, 0, X16_PSG_PAN_BOTH)
    END IF

    k = x16_key_get()
LOOP UNTIL k <> 0

' ---- cleanup --------------------------------------------------------
CALL x16_irq_remove()
CALL x16_psg_init()
CALL x16_sprites_off()
CALL x16_screen_cls()
END
