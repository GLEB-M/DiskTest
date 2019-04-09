BLACK        equ 00000000b
BLUE         equ 00000001b
GREEN        equ 00000010b
CYAN         equ 00000011b
RED          equ 00000100b
PINK         equ 00000101b
BROWN        equ 00000110b
GRAY         equ 00000111b
DARK_GRAY    equ 00001000b
BRIGHT_BLUE  equ 00001001b
BRIGHT_GREEN equ 00001010b
BRIGHT_RED   equ 00001100b
BRIGHT_PINK  equ 00001101b
YELLOW       equ 00001110b
WHITE        equ 00001111b

BLOCK_SZ     equ 127

macro SET_FONT v1, v2
{
   mov [char_font], v2
   shl byte[char_font], 4
   or byte[char_font], v1
}

macro SET_CURSOR v1, v2
{
   mov [cursor_x], v1
   mov [cursor_y], v2
}

macro PRINT_CHAR v1
{
   mov cl, v1
   call print_char
}

macro PRINT_STR v1
{
   push  v1
   call print_str
}

macro PRINT_STR_XY v1, v2, v3
{
   mov [cursor_x], v1
   mov [cursor_y], v2
   push  v3
   call print_str
}


code:
   cli
   mov ax, 0x800   ;  0x800 segment
   mov ds, ax
   mov es, ax
   mov ss, ax
   mov sp, 0xFFFF
   sti

   call init_screen

   call calc_cpu_clock
   call calc_delays

   call clear_screen
   call draw_interface

   call get_drives

   call draw_drives

   @key:
        mov ah, 0x0
        int 0x16
        cmp ah, 0x48
        je @keyup
        cmp ah, 0x50
        je @keydown
        cmp ah, 0x1C
        je @keyenter
        cmp ah, 0x44
        je @keyf12

        @keyup:
            cmp [current_drive], 0
            je @key
            dec [current_drive]
            call draw_drives
        jmp @key

        @keydown:
            mov ax, [max_drives]
            dec ax
            cmp ax, [current_drive]
            je @key
            inc [current_drive]
            call draw_drives
        jmp @key

        ; scan
        @keyenter:
            call reset_scan
            SET_FONT WHITE, BLUE
            PRINT_STR_XY 1, 24, s_control2
            SET_FONT BLUE, GRAY
            mov al, byte[current_drive]
            mov byte[disk], al
            mov dword[block_size], BLOCK_SZ
            call scan_drive
            SET_FONT WHITE, BLUE
            PRINT_STR_XY 1, 24, s_control
            SET_FONT BLUE, GRAY
        jmp @key

        ; reboot
        @keyf12:
           mov word[0x472], 0x1234
           mov al, 0xFE
           out 0x64, al
           hlt
        jmp @key

   jmp @key

   jmp $


draw_drives:
   mov [drive_index], 0
   @@ddr:
   SET_FONT BLUE, GRAY

   mov dx, [drive_index]
   add dx, 19
   SET_CURSOR 0, dx

   mov dx, [current_drive]
   cmp dx, [drive_index]
   jne @f
   SET_FONT BLUE, CYAN
   @@:

   ; HDD
   PRINT_CHAR 221
   PRINT_STR s_hdd
   PRINT_CHAR 222

   mov [cursor_x], 4
   push [drive_index]
   call print_dec

   PRINT_STR s_splitter

   mov bx, [drive_index]
   shl bx, 2
   mov eax, dword[drives + bx]
   cmp dword[drives + bx], 2097152
   jb @f
   shr eax, 10
   @@:
   shr eax, 10
   shl eax, 9
   shr eax, 10
   call print_dec32
   PRINT_CHAR 'G'
   mov bx, [drive_index]
   shl bx, 2
   cmp dword[drives + bx], 2097152
   jge @f
   dec [cursor_x]
   PRINT_CHAR 'M'
   @@:

   inc [drive_index]

   mov ax, [drive_index]
   cmp ax, [max_drives]
   jne @@ddr

   ret

; ********************************** Procedures ***********************************;

init_screen:
   ; 80x25
   mov ax, 0x3
   int 0x10
   ; hide cursor
   mov ah, 0x1
   mov cx, 0x2607
   int 0x10
   ret

clear_screen:
   SET_CURSOR 0, 0
   SET_FONT BLUE, GRAY
   mov cx, 2000
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b
   SET_CURSOR 0, 0
   ret

; cl - char
print_char:
   cmp [cursor_x], 80
   jb @f
   mov [cursor_x], 0
   inc [cursor_y]
   @@:
   cmp [cursor_y], 25
   jb @f
   mov [cursor_y], 0
   @@:
   xor dx, dx
   mov ax, [cursor_y]
   mov bx, 80
   mul bx
   add ax, [cursor_x]
   mov bx, 2
   mul bx

   mov bx, ax

   push 0xB800
   pop es

   mov byte[es:bx], cl
   mov ch, [char_font]
   mov byte[es:bx + 1], ch

   inc [cursor_x]

   ret

print_str:
   push bp
   mov bp, sp
   mov si, [bp + 4]

   @@:
      cmp byte[si], 0
      je @f
      mov cl, byte[si]
      call print_char
      inc si
   jmp @b
   @@:

   pop bp
   ret 2

print_dec:
   push bp
   mov bp, sp
   mov ax, [bp + 4]

   push 0

   @@:
      xor dx, dx
      mov bx, 10
      div bx
      add dl, 0x30
      push dx
      cmp ax, 0
      jne @b
   @@:
      pop dx
      cmp dx, 0
      je @f
      mov cl, dl
      call print_char
      jmp @b
   @@:

   pop bp
   ret 2

; EAX
print_dec32:
   mov si, buff
   mov cx, 10
   @@:
      mov byte[si], ' '
      inc si
   loop @b

   xor si, si
   @@:
      xor edx, edx
      mov ebx, 10
      div ebx
      add dl, 0x30
      mov byte[buff + si], dl
      inc si
      cmp eax, 0
      jne @b

   mov si, buff + 9
   mov cx, 10
   @@1:
      cmp byte[si], ' '
      je @f
      push cx
      mov cl, byte[si]
      call print_char
      pop cx
      @@:
      dec si
   loop @@1

   ret
   buff db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', 0


get_time:
   mov ah, 0x0
   int 0x1A

   xor eax, eax
   mov ax, cx
   shl eax, 16
   mov ax, dx

   ret


draw_interface:
   SET_FONT WHITE, BLUE

   ; top header
   SET_CURSOR 0, 0
   mov cx, 80
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b

   ; title
   SET_CURSOR 1, 0
   push title
   call print_str

   ; bottom header
   SET_CURSOR 0, 24
   mov cx, 80
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b

   PRINT_STR_XY 1, 24, s_control

   SET_FONT BLUE, GRAY

   ; left border
   mov cx, 23
   @@:
      push cx
      SET_CURSOR 0, cx
      PRINT_CHAR 221
      pop cx
   loop @b

   ; right border
   mov cx, 23
   @@:
      push cx
      SET_CURSOR 79, cx
      PRINT_CHAR 222
      pop cx
   loop @b

   ; middle border
   mov cx, 23
   @@:
      push cx
      SET_CURSOR 57, cx
      PRINT_CHAR 222
      pop cx
   loop @b

   ; drives border
   SET_FONT WHITE, BLUE

   SET_CURSOR 0, 18
   mov cx, 58
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b

   PRINT_STR_XY 1, 18, s_drives

   ; BLACK TOP HEADER
   SET_CURSOR 0, 1
   SET_FONT BLUE, BLACK
   PRINT_CHAR 221

   mov cx, 56
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b

   PRINT_CHAR 222

   ; BLACK DOWN HEADER
   SET_CURSOR 0, 17
   SET_FONT BLUE, BLACK
   PRINT_CHAR 221

   mov cx, 56
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b

   PRINT_CHAR 222

   ; BLACK TOP HEADER blocks
   SET_FONT BLUE, BLACK

   SET_CURSOR 58, 1
   mov cx, 21
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b

   PRINT_CHAR 222

   ; BLACK TOP HEADER errors
   SET_CURSOR 58, 9
   mov cx, 21
   @@:
      push cx
      PRINT_CHAR ' '
      pop cx
   loop @b

   PRINT_CHAR 222

   ; block times
   SET_FONT BLUE, GRAY
   PRINT_STR_XY 59, 2, s_blocks_5
   PRINT_STR_XY 59, 3, s_blocks_20
   PRINT_STR_XY 59, 4, s_blocks_50
   PRINT_STR_XY 59, 5, s_blocks_200
   PRINT_STR_XY 59, 6, s_blocks_500
   PRINT_STR_XY 59, 7, s_blocks_o500
   PRINT_STR_XY 59, 8, s_blocks_unc

   ; blocks/errors
   SET_FONT GRAY, BLACK
   PRINT_STR_XY 59, 1, s_blocks
   PRINT_STR_XY 59, 9, s_errors

   ; clear bad sectors list
   SET_FONT BLUE, GRAY
   mov [cursor_y], 10
   mov cx, 14
   @@:
      push cx
      mov [cursor_x], 58
      PRINT_STR s_empty
      PRINT_CHAR 222
      inc [cursor_y]
      pop cx
   loop @b

   ; legend
   SET_CURSOR 1, 1
   SET_FONT DARK_GRAY, BLACK
   PRINT_CHAR 254
   SET_FONT GRAY, BLACK
   PRINT_STR s_unch_block

   SET_CURSOR 23, 1
   SET_FONT GREEN, BLACK
   PRINT_CHAR 254
   SET_FONT GRAY, BLACK
   PRINT_STR s_good_block

   SET_CURSOR 43, 1
   SET_FONT RED, BLACK
   PRINT_CHAR 254
   SET_FONT GRAY, BLACK
   PRINT_STR s_bad_block

   call draw_map

   ret


calc_cpu_clock:
   ; get time
   mov ah, 0x0
   int 0x1A
   mov word [d0], dx
   mov word [d0 + 2], cx

   ; wait next tick
   @@:
   mov ah, 0x0
   int 0x1A
   mov word [d], dx
   mov word [d + 2], cx
   mov eax, dword[d]
   sub eax, dword[d0]
   cmp eax, 0
   je @b

   ; set d0
   mov ah, 0x0
   int 0x1A
   mov word [d0], dx
   mov word [d0 + 2], cx

   ; start time
   rdtsc
   mov dword [t0_l], eax
   mov dword [t0_h], edx

   ; wait 1 sec
   @@:
   mov ah, 0x0
   int 0x1A
   mov word [d], dx
   mov word [d + 2], cx
   mov eax, dword[d]
   sub eax, dword[d0]
   cmp eax, 18
   jb @b

   ; finish time
   rdtsc
   sub edx, dword [t0_h]
   cmp eax, dword [t0_l]
   jb @f
   dec dword[t0_h]
   @@:
   sub eax, dword [t0_l]

   mov dword[cpu_clock], eax

   ret

   t0_h dd 0
   t0_l dd 0
   d0   dd 0
   d    dd 0


calc_delays:
   ; 5 ms
   xor edx, edx
   mov eax, dword[cpu_clock]
   mov ebp, 200
   div ebp
   mov dword[ticks_5], eax

   ; 20 ms
   xor edx, edx
   mov eax, dword[cpu_clock]
   mov ebp, 50
   div ebp
   mov dword[ticks_20], eax

   ; 50 ms
   xor edx, edx
   mov eax, dword[cpu_clock]
   mov ebp, 20
   div ebp
   mov dword[ticks_50], eax

   ; 200 ms
   xor edx, edx
   mov eax, dword[cpu_clock]
   mov ebp, 5
   div ebp
   mov dword[ticks_200], eax

   ; 500 ms
   xor edx, edx
   mov eax, dword[cpu_clock]
   mov ebp, 2
   div ebp
   mov dword[ticks_500], eax

   ret


check_edd:
   or  dl, 0x80
   mov ah, 0x41
   mov bx, 0x55AA
   int 0x13
   jnc @f
   mov ax, 0
   ret
   @@:
   mov ax, 1
   ret

; DL - drive
get_drive_parameters:

   mov word[dev_info], 26
   or  dl, 0x80
   mov ah, 0x48
   mov si, dev_info
   int 0x13

   jnc @f
   mov ax, 0
   ret
   @@:
   mov ax, 1
   ret


; DL - drive
read_sector:

   jmp sc3

   cmp dword[dap + 8], 127
   jne sc

   mov ax, 0
   ret
sc:
   cmp dword[dap + 8], 200
   jne sc2
   mov ax, 0
   ret
sc2:
      cmp dword[dap + 8], 250
   jne sc3
   mov ax, 0
   ret

   sc3 :

   mov byte[dap], 16
   or  dl, 0x80
   mov ah, 0x42
   mov si, dap
   int 0x13
   jnc @f
   mov ax, 0
   ret
   @@:
   mov ax, 1
   ret


verify_sectors:
   mov byte[dap], 16
   or  dl, 0x80
   mov ah, 0x44
   mov si, dap
   int 0x13
   jnc @f
   mov ax, 0
   ret
   @@:
   mov ax, 1
   ret


; DL - drive
recalibrate_drive:
   or  dl, 0x80
   mov ah, 0x11
   int 0x13
   jnc @f
   mov ax, 0
   ret
   @@:
   mov ax, 1
   ret

;**********************************************************************;
;                                                                      ;
;                            Get Drives List                           ;
;                                                                      ;
;**********************************************************************;

get_drives:

   mov dx, 0  ; drive num
   mov bx, 0
   mov cx, 5
   @@gd1:
      push cx
      push bx
      push dx

      call get_drive_parameters

      pop dx
      inc dx

      pop bx
      cmp ax, 1
      jne @@gd2
          mov eax, dword[dev_info + 16]
          mov dword[drives + bx], eax
          add bx, 4
          inc [max_drives]
      @@gd2:

      pop cx
   loop @@gd1
   ret

;**********************************************************************;
;                                                                      ;
;                            Scan Block                                ;
;                                                                      ;
;**********************************************************************;
scan_sectors:

   mov ah, 0x1 ; get keyb buffer
   int 0x16
   jz @scan

   cmp ah, 1   ; ESC pressed
   je @user_abort

   mov ah, 0x0 ; reset keyb buffer
   int 0x16

   jmp @scan

  @user_abort:
   mov ah, 0x0 ; reset keyb buffer
   int 0x16
   mov ax, 0
   ret

  @scan:
   mov edx, dword[block_size]
   mov byte[dap + 2], dl

   ; start time
   rdtsc
   mov dword [t0_l], eax
   mov dword [t0_h], edx

   ; read block
   mov dl, [disk]
   call read_sector
   ;call verify_sectors
   push ax

   ; finish time
   rdtsc
   sub edx, dword [t0_h]
   cmp eax, dword [t0_l]
   jb @f
   dec dword[t0_h]
   @@:
   sub eax, dword [t0_l]
   mov dword[block_time], eax

   ; check read_sector result
   pop ax
   cmp ax, 1
   je scan_success
   ; error detected! now we test each sector
   call draw_bad_blocks

   mov byte[dap + 2], 1
   mov cx, word[block_size]
   scan_each:
      push cx
      mov dl, [disk]
      call read_sector
      cmp ax, 1
      je @f
      ; bad sector (
      call add_bad_to_list
      @@:

      inc dword[dap + 8]
      inc dword[scanned_lba]

      pop cx
   loop scan_each
   mov ax, 1
   ret

   scan_success:

   call calc_blocks_speed

   mov eax, dword[block_size]
   add dword[dap + 8], eax

   add dword[scanned_lba], eax

   mov ax, 1
   ret


;**********************************************************************;
;                                                                      ;
;                            Get Drive                                 ;
;                                                                      ;
;**********************************************************************;
scan_drive:
   ; get geomtery
   mov dl, [disk]
   call get_drive_parameters
   cmp ax, 0
   jne @f
   mov ax, 0
   ret
   @@:

   ; set head to sector 0
   SET_FONT GRAY, BLACK
   PRINT_STR_XY 1, 17, s_recal

   mov dl, [disk]
   call recalibrate_drive

   mov dword[scanned_lba], 0

   xor edx, edx
   mov eax, dword[dev_info + 16]
   mov dword[total_lba], eax
   mov ebp, [block_size]
   div ebp
   mov dword[scan_blocks], eax
   cmp edx, 0
   je @f
   inc dword[scan_blocks]
   @@:

   mov dword[scan_block], 1

   mov word[dap + 4],   0x0      ; offset
   mov word[dap + 6],   0x1800   ; segment
   mov dword[dap + 8],  0        ; start sector (low)
   mov dword[dap + 12], 0        ; start sector (high)

   @@scan:
      mov eax, dword[block_size]
      cmp dword[dev_info + 16], eax
      jge @f
      mov eax, dword[dev_info + 16]
      mov dword[block_size], eax
      @@:

      call scan_sectors
      cmp ax, 0
      je sc_e

      call scan_progress

      mov eax, dword[block_size]
      sub dword[dev_info + 16], eax

      cmp dword[dev_info + 16], 0
      jne @@scan
   ; user abort
   sc_e:
   mov ax, 1
   ret

scan_progress:
   SET_FONT GRAY, BLACK

   PRINT_STR_XY 1, 17, s_scan

   mov eax, dword[scanned_lba]
   call print_dec32
   PRINT_CHAR '/'
   mov eax, dword[total_lba]
   call print_dec32

   xor edx, edx
   mov eax, dword[scan_block]
   mov ebp, 100
   mul ebp
   mov ebp, dword[scan_blocks]
   div ebp
   mov dword[perc], eax

   PRINT_STR s_progress

   mov eax, dword[perc]
   call print_dec32

   PRINT_CHAR '%'

   inc dword[scan_block]

   ; calc disk speed
   mov eax, dword[scanned_lba]
   sub eax, dword[speed_last]
   add dword[speed_disk], eax

   mov eax, dword[scanned_lba]
   mov dword[speed_last], eax

   call get_time
   mov edx, eax ; save time
   sub eax, dword[speed_time]
   cmp eax, 18
   jb @f
   mov dword[speed_time], edx

   mov eax, dword[speed_disk]
   shr eax, 10
   shl eax, 9
   shr eax, 10
   mov dword[speed_out], eax

   mov dword[speed_disk], 0
   @@:

   PRINT_STR s_splitter
   mov eax, dword[speed_out]
   call print_dec32
   PRINT_STR s_speed

   SET_FONT BLUE, GRAY

   call mark_map_block

   ret

   perc dd 0


add_bad_to_list:

   cmp dword[bad_sectors], 14   ; FIX IT! (14 is the size of bad block list)
   jne @f
   ret
   @@:

   mov ebx, dword[bad_sectors]
   shl ebx, 2
   mov eax, dword[dap + 8]
   mov dword[bad_sectors_list + ebx], eax

   inc dword[bad_sectors]

   ; draw
   SET_FONT WHITE, RED
   mov [cursor_y], 10
   mov bx, 0
   mov cx, word[bad_sectors]
   @@:
      push cx
      push bx

      mov [cursor_x], 58

      PRINT_STR s_empty
      SET_FONT BLUE, RED
      PRINT_CHAR 222
      SET_FONT WHITE, RED
      pop bx
      push bx
      mov [cursor_x], 59

      mov si, bx
      shl si, 2
      mov eax, dword[bad_sectors_list + si]
      call print_dec32

      pop bx

      inc bx

      inc [cursor_y]

      pop cx
   loop @b

   SET_FONT BLUE, GRAY

   ret


draw_bad_blocks:
   SET_FONT BLUE, GRAY
   inc dword[blocks_bad]
   mov [map_bad_block], 1
   SET_CURSOR 69, 8
   mov eax, dword[blocks_bad]
   call print_dec32
   ret

calc_blocks_speed:
   SET_FONT BLUE, GRAY

   mov eax, dword[block_time]

   cmp eax, dword[ticks_500]
   jbe check_block500
   jmp add_block_o500

  check_block500:
   cmp eax, dword[ticks_200]
   jg add_block500
   jbe check_block200

  check_block200:
   cmp eax, dword[ticks_50]
   jg add_block200
   jbe check_block50

  check_block50:
   cmp eax, dword[ticks_20]
   jg add_block50
   jbe check_block20

  check_block20:
   cmp eax, dword[ticks_5]
   jg add_block20
   jbe add_block5

  add_block5:
   inc dword[blocks_5]
   SET_CURSOR 69, 2
   mov eax, dword[blocks_5]
   jmp print_block

  add_block20:
   inc dword[blocks_20]
   SET_CURSOR 69, 3
   mov eax, dword[blocks_20]
   jmp print_block

  add_block50:
   inc dword[blocks_50]
   SET_CURSOR 69, 4
   mov eax, dword[blocks_50]
   jmp print_block

  add_block200:
   inc dword[blocks_200]
   SET_CURSOR 69, 5
   mov eax, dword[blocks_200]
   jmp print_block

  add_block500:
   inc dword[blocks_500]
   SET_CURSOR 69, 6
   mov eax, dword[blocks_500]
   jmp print_block

  add_block_o500:
   inc dword[blocks_o500]
   SET_CURSOR 69, 7
   mov eax, dword[blocks_o500]
   jmp print_block

  print_block:
   call print_dec32
   ret


draw_map:

   SET_FONT DARK_GRAY, GRAY
   SET_CURSOR 1, 2
   mov cx, 840
   @d_m:
      push cx
      PRINT_CHAR 254
      cmp [cursor_x], 57
      jne @f
      mov [cursor_x], 1
      inc [cursor_y]
      @@:
      pop cx
   loop @d_m
   SET_FONT BLUE, GRAY
   ret

; EAX - block
mark_map_block:
   SET_FONT GREEN, GRAY
   mov eax, dword[scan_block]
   sub eax, 2 ;  scan_block - 2
   xor edx, edx
   mov ebp, 840
   mul ebp
   ;xor edx, edx   ; do not clear EDX else 32 Bit OVERFLOW detected!
   mov ebp, dword[scan_blocks]
   div ebp

   xor edx, edx
   mov ebp, 56
   div ebp
   add eax, 2
   mov [cursor_y], ax  ; Y
   add edx, 1
   mov [cursor_x], dx  ; X

   push [cursor_y]
   push [cursor_x]

   ; check prev
   cmp ax, [map_prev_y]
   jne @mark
   cmp dx, [map_prev_x]
   jne @mark
   cmp [map_bad_block], 1
   je @mark
   jmp @no_mark

  @mark:
   cmp [map_bad_block], 1
   jne @f
   SET_FONT RED, GRAY
   mov [map_bad_block], 0
  @@:
   PRINT_CHAR 254

  @no_mark:
   SET_FONT BLUE, GRAY

   pop [map_prev_x]
   pop [map_prev_y]

   ret

reset_scan:
   mov [block_size],  0
   mov [scan_block],  0
   mov [scan_blocks], 0
   mov [scanned_lba], 0
   mov [total_lba],   0
   mov [blocks_5],    0
   mov [blocks_20],   0
   mov [blocks_50],   0
   mov [blocks_200],  0
   mov [blocks_500],  0
   mov [blocks_o500], 0
   mov [blocks_bad] , 0
   mov [bad_sectors], 0

   mov [map_prev_x], 0xFFFF
   mov [map_prev_y], 0xFFFF
   mov [map_bad_block], 0

   mov dword[speed_time], 0
   mov dword[speed_disk], 0
   mov dword[speed_last], 0
   mov dword[speed_out], 0

   call draw_interface
   call draw_drives
   ret


; ********************************  Data  ***************************************** ;

cursor_x      dw 0
cursor_y      dw 0
char_font     db 0


cpu_clock     dd 0
ticks_5       dd 0
ticks_20      dd 0
ticks_50      dd 0
ticks_200     dd 0
ticks_500     dd 0


disk          db 0
block_size    dd 0
scan_block    dd 0
scan_blocks   dd 0
scanned_lba   dd 0
total_lba     dd 0


block_time    dd 0
blocks_5      dd 0
blocks_20     dd 0
blocks_50     dd 0
blocks_200    dd 0
blocks_500    dd 0
blocks_o500   dd 0
blocks_bad    dd 0
bad_sectors   dd 0


map_prev_x    dw 0xFFFF
map_prev_y    dw 0xFFFF
map_bad_block db 0


speed_time    dd 0
speed_disk    dd 0
speed_last    dd 0
speed_out     dd 0


max_drives    dw 0
drive_index   dw 0
current_drive dw 0

drives:
         dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


bad_sectors_list:
     times 50 dd 0


dev_info:
         dw 0    ;size
         dw 0    ;info
         dd 0    ;cyl
         dd 0    ;head
         dd 0    ;secpertrack;
         dd 0    ;sectors_lo;
         dd 0    ;sectors_hi;
         dw 0    ;bytespersec;

dap:
         db 0    ;size;
         db 0    ;reserved1;
         db 0    ;count;
         db 0    ;reserved2;
         dw 0    ;offset;
         dw 0    ;segment;
         dd 0    ;sector_lo;
         dd 0    ;sector_hi;



title         db "GL DiskTest", 0
s_control     db 24, 25, " - Select drive    ENTER - Begin test    F10 - Reboot", 0
s_control2    db "ESC - Stop test                                        ", 0
s_blocks_5    db 254, " 5ms   :           ", 0
s_blocks_20   db 254, " 20ms  :           ", 0
s_blocks_50   db 254, " 50ms  :           ", 0
s_blocks_200  db 254, " 200ms :           ", 0
s_blocks_500  db 254, " 500ms :           ", 0
s_blocks_o500 db 254, " >500ms:           ", 0
s_blocks_unc  db 254, " UNC   :           ", 0
s_blocks      db "Blocks", 0
s_errors      db "Errors", 0
s_drives      db "Drives", 0
s_progress    db " LBA - ", 0
s_hdd         db "HDD                                                     ", 0
s_speed       db "MB/s     ", 0
s_splitter    db " - ", 0
s_empty       db "                     ", 0
s_unch_block  db " - Unchecked block", 0
s_good_block  db " - Checked block", 0
s_bad_block   db " - Bad block", 0
s_recal       db "Recalibrate...", 0
s_scan        db "Scan ", 0
