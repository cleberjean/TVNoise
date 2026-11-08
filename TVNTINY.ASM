;*****************************************************************************
; Screen Saver "TVNoise" - Tiny Version
; * Only LFSRs, Keyboard Checking, Gray Pallete Generation and Effect Loop *
; By Cleber Jean Barranco (cleberjean@hotmail.com)
; First version in 01/Jan/2003.
; Last change in 04/Nov/2026.
;
; Uses BP and BL to store the LFSR seeds for dots positions on screen and
; the dot bright intensity (gray level).
; DX stores the initial seed for the dot position LFSR.
;
; Compile with: "nasm tvntiny.asm -o tvntiny.com"
;
;*****************************************************************************


;Directives to compilation
    cpu   8086                     ; Generate binary for 8086 (MANDATORY for
                                   ; Nasm do not generate 80286 code).
    org   100h                     ; Program is a .COM file


;-----------------------------------------------------------------------------
; Constants
;-----------------------------------------------------------------------------
    LFSR_XOR_POS_MASK   equ 0xB400 ; XOR mask for LFSR computing
    LFSR_MAX_PERIOD     equ 64000  ; Fill all 64000 bytes from screen 320x200
    LFSR_XOR_GRAY_MASK  equ 0xB8   ; XOR mask for gray level LFSR
    ESC_KEY             equ 0x1B   ; Esc key ASCII code
    LFSR_POS_INIT_SEED  equ 0x5555 ; 0101010101010101b
    LFSR_GRAY_INIT_SEED equ 0xAA   ; 10101010b


;-----------------------------------------------------------------------------
; Change Video Mode to 320x200 by 256 Colors
; ==========================================
;
; Assumes AX = 0000h.
;-----------------------------------------------------------------------------
Start:    
    mov   al,13h                   ; Select video mode 13h
    int   10h                      ; Change to MCGA (320x200x256)


;-----------------------------------------------------------------------------
; Starts the Gray Pallete Generation
; ==================================
;
; Generates 4 gray scales from 0 to 255. (This solves the full black color 0
; (RGB = 000) issue due the LFSR restriction (of not to allow zero value),
; where we will have full back intensity on colors index 64, 128 and 192)
;;-----------------------------------------------------------------------------
Init_Pallete:
    xor   ax,ax                    ; AL = 0
    mov   dx,03C8h
;    cli                            ; Stop interrupts
    out   dx,al                    ; Informs to VGA the 1st color value from pallete
    inc   dx                       ; DX = 03C9h


; Create 4 x 64 Gray Tones Pallete
Gen_Pallete:
    out   dx,al                    ; Puts Red value
    out   dx,al                    ; Puts Green value
    out   dx,al                    ; Puts Blue value
    inc   al                       ; Increments the gray intensity
    jnz   Gen_Pallete              ; Checks for 256 color index generated
;    sti                            ; Renable interrupts


;-----------------------------------------------------------------------------
; Init LFSR Generator and the Seed for LFSR Gray Generator
;-----------------------------------------------------------------------------
    mov   dx,LFSR_POS_INIT_SEED
    mov   bp,dx
    mov   bl,LFSR_GRAY_INIT_SEED   ; BL stores the LFSR seed of gray level


;-----------------------------------------------------------------------------
; Init VGA Register
;-----------------------------------------------------------------------------
    mov   ah,0A0h                  ; VGA 320x200x256 segment (AL was cleaned 
                                   ; by the Gen_Pallete)
    mov   es,ax                    ; Now ES will point to VGA
    

;-----------------------------------------------------------------------------
; Start of Noise Loop
; ===================
;
; Checks the keyboard at each screen full (64000 dots plotted) for a fast
; effect.
;-----------------------------------------------------------------------------
Noise_Loop:


;-----------------------------------------------------------------------------
; Galois LFSR Gray Raffle
; =======================
;
; Uses BL to store the LFSR seed for the gray level (bright intensity).
;
; Input : BL = LFSR seed for gray level
; Output: AL = Gray level (1 - 63, 64 - 127, 128 - 191, 192 - 255)
;         BL = LFSR seed for next calculation
;-----------------------------------------------------------------------------
    shr   bl,1
    jnc   Skip_Gray_XOR
    xor   bl,LFSR_XOR_GRAY_MASK

Skip_Gray_XOR:
    mov   al,bl                    ; Copies seed to AL
    
    
;-----------------------------------------------------------------------------    
; Plots a Gray Dot on a Random Coordinate    
;-----------------------------------------------------------------------------    
    mov   di,bp                    ; Copies LFSR number to DI
    dec   di                       ; This allow to plot at the coordinate 0,0
    stosb                          ; Plots the gray dot


;-----------------------------------------------------------------------------
; Galois LFSR Dot Position Generator
; ==================================
;
; Since LFSR does not generate the value 0 (is forbidden), we must
; generate a period from 1 to 64000, to can obtain the value 0 (BP = 1), 
; by decrementing BP before using it and incrementing it again after use,
; to back it to a non zero value, since BP stores the LFSR seed throughout 
; the program.
;-----------------------------------------------------------------------------
Get_Dot_Position:
    shr   bp,1
    jnc   Check_Bound
    xor   bp,LFSR_XOR_POS_MASK

; Checks Value Limit (not used if period is 65536)
Check_Bound:
    cmp   bp,LFSR_MAX_PERIOD
    ja    Get_Dot_Position         ; Gen another number if number >= max period
                                   ; JA allow generate from 0 up to maximum
                                   ; period - 1, by decrementing BP, using
                                   ; it and incrementing it again to
                                   ; correct it for a non zero value.
    cmp   bp,dx                    ; Were all 64000 dots plotted?
    jne   Noise_Loop               ; Not yet

; Checks Keyboard    
    mov   ah,01h
    int   16h                      ; Checks if any key was pressed
    jz    Noise_Loop               ; None key. Then generates other 64000 dots

; Reads Keyboard Buffer (get pressed key)
    xor   ah,ah
    int   16h                      ; Gets the value of the pressed key
    cmp   al,ESC_KEY               ; Was Esc key pressed?
    jne   Noise_Loop               ; No. Then generates other 64000 dots


;-----------------------------------------------------------------------------
; Program End
;-----------------------------------------------------------------------------
    mov   ax,0003h
    int   10h                      ; Backs to the mode 03h
    ret                            ; Backs to DOS (jumps to CS:0000h that has
                                   ; an instruction INT 20h)

