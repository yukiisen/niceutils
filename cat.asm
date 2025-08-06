section .data
    NEWLINE db 10, 0
    NOTFOUND_MSG db "Error: File not found", 10, 0
    NFM_LEN equ $ - NOTFOUND_MSG
    NOPERMISSION_MSG db "Error: Cannot open file, permission denied", 10, 0
    PM_LEN equ $ - NOPERMISSION_MSG
    UNKNOWN_ERR db "Error: Unknown", 10, 0
    UE_LEN equ $ - UNKNOWN_ERR

    ERRFUCK db "Fuck this", 10, 0
    EF_LEN equ $ - ERRFUCK

    ENOENT equ 2
    EACCES equ 13

    bufferlen equ 1024

section .bss
    buffer resb 1024
    dbuf resb 20

section .text
    global _start
    global has_arg

%macro sys_write 3 ; three args
    mov rdi, %1
    mov rsi, %2
    mov rdx, %3
    mov rax, 1 ; write operation
    syscall
%endmacro

_start:
    mov r8, rsp ; r8 isn't allowd to change from now on :)

    ; steps (basic)
    ; get first arg (not flag)
    ; set fd to it
    ; if no set it to 0
    ; read and print until you get 0

    xor r12, r12 ; first file (we're looping)

    .out_loop:
    inc r12

    ; --- debug: print r12 --- 
    ; NOTE: I didn't know why I can't use rcx here, I'll come back later :)
    ; push rax
    ; push r12
    ; mov rax, r12
    ; call print_rax
    ; pop r12
    ; pop rax
    ; --- end debug ---

    mov rdi, r12 ; counter to first arg
    call ncmd ; get file
    cmp rax, -1
    je .stdin ; use stdin of no file
    
    .file:
    mov rdi, rax
    xor rsi, rsi
    xor rdx, rdx
    mov rax, 2
    syscall
    cmp rax, 0
    jl .error ; handle error
    mov rdi, rax ; move fd to rdi
    jmp .read_loop

    .stdin:
    cmp r12, 1
    jg .exit ; exit if this is not the first file
    mov rdi, 0 ; use stdin

    .read_loop:
    mov rsi, buffer
    mov rdx, bufferlen
    mov rax, 0 ; read
    syscall

    cmp rax, 0
    jl .error
    je .cleanup
    
    push rdi

    mov rdi, 1
    mov rdx, rax ; chunk len
    mov rax, 1
    syscall

    pop rdi

    jmp .read_loop ; next chunk

    .cleanup:
    cmp rdi, 0
    je .out_loop ; don't close stdin
    mov rax, 3 ; rdi is already holding the fd
    syscall
    jmp .out_loop ; next file
    
    .error:
    neg rax ; get error
    cmp rax, ENOENT
    je .error_nf
    cmp rax, EACCES
    je .error_perm

    jmp .error_unknown

    .error_nf:
    sys_write 2, NOTFOUND_MSG, NFM_LEN
    jmp .exit
    .error_perm:
    sys_write 2, NOPERMISSION_MSG, PM_LEN
    jmp .exit
    .error_unknown:
    sys_write 2, UNKNOWN_ERR, UE_LEN

    .exit:
    mov rax, 60
    xor rdi, rdi ; exit with 0 code
    syscall

ncmd: ; takes one arg which is index of the command (arg) and returns a pointer to the command (alters args)
    push rbp
    mov rbp, rsp
    mov rsp, r8 ; back to start

    ; xor rcx, rcx
    mov rcx, 1 ; skip bin name
    mov rbx, [rsp] ; argc

    .ncmd_loop:
        inc rcx
        cmp rcx, rbx
        jg .ncmd_notfound ; return if args are over

        mov rax, [rsp+rcx*8]

        cmp byte [rax], '-'
        je .ncmd_loop

        dec rdi
        test rdi, rdi
        jnz .ncmd_loop
        jmp .ncmd_done ; skip the error

    .ncmd_notfound:
    mov rax, -1; return -1 on error

    .ncmd_done:

    mov rsp, rbp
    pop rbp
    ret

; -- for debug purposes, don't assemble --
; print_rax:
;     push rax
;     push rcx
;     push rdx
;     push rsi
;     push rdi
;     push rbx

;     mov rbx, 10
;     mov rcx, dbuf
;     add rcx, 20 ; point to end of buffer
;     mov byte [rcx-1], 10 ; newline
;     dec rcx

;     cmp rax, 0
;     jne .convert
;     mov byte [rcx], '0'
;     jmp .done

; .convert:
;     xor rdx, rdx
; .loop:
;     div rbx ; rax / rbx => rdx (remain), rax (result)
;     add dl, '0'
;     dec rcx
;     mov [rcx], dl
;     xor rdx, rdx
;     test rax, rax
;     jnz .loop

; .done:
;     ; write(1, rcx, dbuf+20 - rcx)
;     mov rax, 1
;     mov rdi, 1
;     mov rsi, rcx
;     mov rdx, dbuf+20
;     sub rdx, rcx
;     syscall

;     pop rbx
;     pop rdi
;     pop rsi
;     pop rdx
;     pop rcx
;     pop rax
;     ret

