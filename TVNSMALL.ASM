;*****************************************************************************
; Screen Saver "TVNoise" Small Version
; * Only LFSRs, Keyboard Checking, Gray Pallete Generation and Effect Loop *
; By Cleber Jean Barranco (cleberjean@hotmail.com)
; First version in 01/Jan/2003.
; Last change in 18/Jun/2026.
;
; Uses BP and BL to store the LFSR seeds for dots positions on screen and
; the dot bright intensity (gray level).
; DX stores the initial seed for the dot position LFSR.
;
; Compile with: "nasm tvnsmall.asm -o tvnsmall.com"
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
;    LFSR_POS_INIT_SEED  equ 0x4197
;    LFSR_GRAY_INIT_SEED equ 0xA7
    LFSR_POS_INIT_SEED  equ 0x5555 ; 0101010101010101b
    LFSR_GRAY_INIT_SEED equ 0xAA   ; 10101010b


;-----------------------------------------------------------------------------
; Change Video Mode to 320x200 by 256 Colors
;-----------------------------------------------------------------------------
Start:    
    mov   ax,0013h                 ; Select video mode 13h
    int   10h                      ; Change to MCGA (320x200x256)


;-----------------------------------------------------------------------------
; Starts the Gray Pallete Generation
;-----------------------------------------------------------------------------
Init_Pallete:
    xor   al,al                    ; Value of the first color
    xor   bx,bx                    ; Initial value fo the Red and Green
    xor   cx,cx                    ; Initial value of the Blue
    mov   dx,03C8h
;    cli                            ; Stop interrupts
    out   dx,al                    ; Informs to VGA the 1st color value from pallete
    inc   dx                       ; DX = 03C9h

; Create a 64 Gray Tones Pallete
Gen_Pallete:
    mov   al,bh
    out   dx,al                    ; Puts Red value (BH)
    mov   al,bl
    out   dx,al                    ; Puts Green value (BL)
    mov   al,cl
    out   dx,al                    ; Puts Blue value (CL)
    inc   bh                       ; Increments Red (BH)
    inc   bx                       ; Increments Green (it's really BX, 1 byte gain)
    inc   cx                       ; Increments Blue (it's really CX, 1 byte gain)
    cmp   cl,40h                   ; Checks if was created all the 64 gray tones
    jne   Gen_Pallete              ; Still no
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
    mov   ax,0A000h                ; VGA 320x200x256 segment
    mov   es,ax                    ; Now ES will point to VGA
    

;-----------------------------------------------------------------------------
; Noise Loop
; Checks keyboard at each screen full (64000 dots plotted)
;-----------------------------------------------------------------------------
Noise_Loop:
    mov   di,bp                    ; Copies LFSR number to DI
    dec   di                       ; This allow to plot at position 0
    call  Get_Gray_Level           ; Raffle the gray level (bright intensity)
    stosb                          ; Plots the gray dot
    call  Get_Dot_Position
    cmp   bp,dx                    ; Were all 64000 dots plotted?
    jne   Noise_Loop               ; Not yet

; Checks Keyboard    
    call  Check_Keyboard           ; Checks keyboard
    cmp   al,ESC_KEY               ; Was Esc key pressed?
    jne   Noise_Loop               ; No. Then generates another 64000 dots


;-----------------------------------------------------------------------------
; Program End
;-----------------------------------------------------------------------------
    mov   ax,0003h
    int   10h                      ; Backs to the mode 03h
    int   20h                      ; Backs to DOS (All DOS versions)


;-----------------------------------------------------------------------------
; Checks Keyboard
;
; Returns AL = 0 if none key was pressed.
;-----------------------------------------------------------------------------
Check_Keyboard:
    mov   ah,01h
    int   16h                      ; Checks if any key was pressed
    jnz   .Get_Keyb_Key            ; Yes, then gets the pressed key
    xor   al,al                    ; Key Code for none key pressed (0)
    ret

; Reads Keyboard Buffer (get pressed key)
.Get_Keyb_Key:
    xor   ah,ah
    int   16h                      ; Gets the value of the pressed key
    ret                            ; Returns with pressed key in AL.


;-----------------------------------------------------------------------------
; Galois LFSR Dot Position Generator
; Since LFSR does not generate the value 0 (is forbidden), we must
; generate a period from 1 to 64000, to can obtain the value 0 (BP = 1), 
; by decrementing BP before using it and incrementing it again after use,
; to back it to a non zero value, since BP stores the LFSR seed throughout 
; the program.
;
; Input : BP = LFSR seed
; Output: BP = New LFSR seed (value from 1 to 64000)
;              Decrement BP value by 1 to get 0 to 63999, but you MUST
;              RESTORE it again, after the use. (Seed can not be 0)
;-----------------------------------------------------------------------------
Get_Dot_Position:
    shr   bp,1
    jnc   .Check_Bound
    xor   bp,LFSR_XOR_POS_MASK

; Checks Value Limit (not used if period is 65536)
.Check_Bound:
    cmp   bp,LFSR_MAX_PERIOD
    ja    Get_Dot_Position         ; Gen another number if number >= max period
                                   ; JA allow generate from 0 up to maximum
                                   ; period - 1, by decrementing BP, using
                                   ; it and incrementing it again to
                                   ; correct it for a non zero value.
    ret


;-----------------------------------------------------------------------------
; Galois LFSR Gray Raffle
; Uses BL to store the LFSR seed for the gray level (bright intensity).
;
; Input : BL = LFSR seed for gray level
; Output: AL = Gray level (0 - 63)
;         BL = LFSR seed for next calculation
;-----------------------------------------------------------------------------
Get_Gray_Level:
    shr   bl,1
    jnc   .Calc_Gray
    xor   bl,LFSR_XOR_GRAY_MASK

.Calc_Gray:
    mov   al,bl                    ; Copies seed to AL
    and   al,3Fh                   ; Ajusts gray level range for 0 to 63
    ret

