;*****************************************************************************
; Screen Saver "TVNoise" Version 7 (LFSR Generator)
; By Cleber Jean Barranco (cleberjean@hotmail.com)
; First version in 01/Jan/2003.
; Last change in 15/Jun/2026
;
; Uses BP and BL to store the LFSR seeds for dots positions on screen and
; the dot bright intensity (gray level).
; DX stores the initial seed for the dot position LFSR.
;
; Compile with: "nasm tvnoise.asm -o tvnoise.com"
;
;*****************************************************************************


;Directives to compilation
    cpu   8086                     ; Generate binary for 8086 (MANDATORY for
                                   ; Nasm do not generate 80286 code).
    org   100h                     ; Program is a .COM file


;-----------------------------------------------------------------------------
; Constants
;-----------------------------------------------------------------------------
    LFSR_XOR_MASK       equ 0xB400 ; XOR mask for LFSR computing
    LFSR_MAX_PERIOD     equ 64000  ; Fill 64000 bytes from screen 320x200
    LFSR_XOR_GRAY_MASK  equ 0xB8
    ESC_KEY             equ 0x1B   ; Esc key ASCII code


;-----------------------------------------------------------------------------
; Program Start
;-----------------------------------------------------------------------------
Start:
    push  cs                       ; Gets code segment
    pop   ds                       ; DS points to vars into program code
    cld                            ; Index registers increments


;-----------------------------------------------------------------------------
; Checks if Video Card is a VGA/MCGA (1A00h function from INT 10h) and aborts
; if is not.
;-----------------------------------------------------------------------------
 Check_VGA_Card:
    mov    ax,1A00h
    int    10h                     ; Checks presence of VGA/MCGA card
    cmp    al,1Ah
    jne    .No_VGA                 ; IF AL != 1Ah video card not is VGA
    cmp    bl,08h
    je     Get_Video_Mode          ; VGA with a color monitor
    cmp    bl,0Ah
    je     Get_Video_Mode          ; MCGA with a color monitor (digital)
    cmp    bl,0Ch
    je     Get_Video_Mode          ; MCGA with a color monitor


;-----------------------------------------------------------------------------
; VGA with an W&B Monitor or is Not a VGA
;-----------------------------------------------------------------------------
.No_VGA:
    mov    dx,Need_VGA_Msg         ; Error message for no VGA video card
    mov    ah,09h
    int    21h                     ; Show error message
    int    20h                     ; Backs to DOS (All DOSes)


;-----------------------------------------------------------------------------
; Gets and Saves the Current Video Mode
;-----------------------------------------------------------------------------
Get_Video_Mode:
    mov   ah,0Fh
    int   10h                      ; Gets current video mode
    mov   ah,bh                    ; Copies current video page in AH
    push  ax                       ; Saves current video mode and page
                                   ; Will restored on before to return to DOS

;-----------------------------------------------------------------------------
; Change Video Mode to 320x200 by 256 Colors
;-----------------------------------------------------------------------------
Set_VGA_Mode:    
    mov   ax,0013h                 ; Select video mode 13h
    int   10h                      ; Change to MCGA (320x200x256)


; Starts the Gray Pallete Generation
Init_Pallete:
    xor   bx,bx                    ; Initial value fo the Red and Green
    xor   cx,cx                    ; Initial value of the Blue
    mov   al,20h                   ; Value of the first color (32)
    cli                            ; Stop interrupts
    mov   dx,03C8h
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
    jnz   Gen_Pallete              ; Still no
    sti                            ; Renable interrupts


;-----------------------------------------------------------------------------
; Init Registers
;-----------------------------------------------------------------------------
    mov   ax,0A000h                ; VGA 320x200x256 segment
    mov   es,ax                    ; Now ES will point to VGA
    

;-----------------------------------------------------------------------------
; Init LFSR Generator and the Seed for LFSR Gray Generator
;-----------------------------------------------------------------------------
Init_LFSRs_Seeds:
    call  Get_Initial_LFSR_Seed
    mov   bx,dx
    xor   bl,bh                    ; BL stores the LFSR seed of gray level
    jz    Init_LFSRs_Seeds         ; LFSR seed CAN NOT be 0!
                                   ; for the LFSR seed of gray level)

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
; Program End      (Note: Video page (AH) is not restored)
;-----------------------------------------------------------------------------
    pop   ax                       ; Restores original video mode (AL)
                                   ; and page (AH)
    xor   ah,ah                    ; Function 0
    int   10h                      ; Backs to original video mode
    int   20h                      ; Backs to DOS (All DOSes)


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
; Initializes Initial FLSR Seed (= RANDOMIZE TIMER in QBasic)
; Gets initial seed from system ticks.
;
; Input : None.
; Output: DX, BP = Initial random seed for the LFSR.
;-----------------------------------------------------------------------------
Get_Initial_LFSR_Seed:
    xor   ah,ah
    int   1Ah                      ; Get system clock ticks since midnight
    xor   dx,cx                    ; XOR between high and low order
    jnz   .Seed_Not_Zero           ; If non zero, store on memory and copies to DI
    inc   dx                       ; Turns seed = 1 (the seed CAN NOT be 0)

.Seed_Not_Zero:
    cmp   dx,LFSR_MAX_PERIOD       ; Checks if seed is on range 1 to 64000
    jbe   .Seed_OK                 ; Is seed > 64000?
    call  Get_Dot_Position         ; Yes, then raffle a new value into
                                   ; period from 1 to 64000.
    mov   dx,bp                    ; Copies the drawn LFSR seed in DX
                                   ; (Register of the initial seed).
.Seed_OK:
    mov   bp,dx                    ; Initializes BP (LFSR Seed Register)
    ret


;-----------------------------------------------------------------------------
; Galois LFSR Number Generator (stored in BP reg by all program execution)
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
    xor   bp,LFSR_XOR_MASK

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
; Uses BL to store the LFSR seed for gray level (bright intensity).
;
; Input : BL = LFSR seed for gray level
; Output: AL = Pallete gray level
;-----------------------------------------------------------------------------
Get_Gray_Level:
    shr   bl,1
    jnc   .Save_Gray
    xor   bl,LFSR_XOR_GRAY_MASK

.Save_Gray:
    mov   al,bl                    ; Copies gray level to AL
    and   al,3Fh                   ; Ajusts gray level period for 0 to 63
    add   al,20h                   ; Ajusts gray level for the pallete
    ret


;-----------------------------------------------------------------------------
; Vars
;-----------------------------------------------------------------------------
;    section .data                 ; NOT IS GOOD USE IT WITH .COM FILES!
                                   ; Adds byte padding, causing confusion
                                   ; with binary code size optimizations.

Need_VGA_Msg    db 0Dh, 0Ah, "I need a VGA video card!", 0Dh, 0Ah, "$"


File_Signature  db "   TVNoise7 - 15jun26   "

