section .data
    NEWLINE db 10, 0

    NOTFOUND_MSG db "Error: File not found", 10, 0
    NFM_LEN equ $ - NOTFOUND_MSG

    NOPERMISSION_MSG db "Error: Cannot open file, permission denied", 10, 0
    PM_LEN equ $ - NOPERMISSION_MSG

    ROFS_MSG db "Error: Readonly file system.", 10, 0
    ROFS_LEN equ $ - ROFS_MSG

    ISDIR_MSG db "Error: Path is a directory.", 10, 0
    ISDIR_LEN equ $ - ISDIR_MSG

    NOTDIR_MSG db "Error: Path is not a directory.", 10, 0
    NOTDIR_LEN equ $ - NOTDIR_MSG

    IOERR_MSG db "Erro: io error", 10, 0
    IOERR_LEN equ $ - IOERR_MSG

    UNKNOWN_ERR db "Error: Unknown", 10, 0
    UE_LEN equ $ - UNKNOWN_ERR

    ERRFUCK db "Fuck this", 10, 0
    EF_LEN equ $ - ERRFUCK

    USAGE db "Usage: cp [...sources] [dest]", 10, 0
    USAGE_LEN equ $ - USAGE

section .bss
    LAST_FILE resq 1 ; holds index of last file arg so we don't use it
    BUFFER resb 4096
    STATBUF resb 256 ; for the statx call (for safety ._.)
    SOURCE_BUFFER resb 4096 ; to manage file names when copying to dirs
    dbuf resb 20 ; for debugging

%define BUFLEN 4096

section .text
    global _start

%macro sys_write 3 ; three args
    mov rdi, %1
    mov rsi, %2
    mov rdx, %3
    mov rax, 1 ; write operation
    syscall
%endmacro

%macro safe_write 3 ; write without fear :)
    push rdi
    push rsi
    push rdx
    push rax

    mov rdi, %1
    mov rsi, %2
    mov rdx, %3
    mov rax, 1 ; write operation
    syscall

    sys_write %1, NEWLINE, 1

    pop rax
    pop rdx
    pop rsi
    pop rdi
%endmacro

%define ENOENT 2
%define EACCES 13
%define EROFS 30
%define EISDIR 21
%define ENOTDIR 20
%define EIO 5

_start:
    mov r15, rsp ; always points the the startup point of the stack

    ; --- plan ---
    ; we check if last arg is a dir
    ; if no we blow up
    ; we loop over other args
    ; if arg is a file we copy it
    ; else we create a directory
    ; I'll do recursion later :)

    ; get dest
    call lcmd ; last arg
    mov rsi, rax
    mov [LAST_FILE], rdx

    cmp rdx, 2
    jl .usage

    mov rax, 332 ; we're going to check
                 ; if we're copying to an existing directory
    mov rdi, -100
    mov rdx, 0
    mov r10, 0x00000001 ; STATX_TYPE
    mov r8, STATBUF
    syscall ; run statx

    cmp rax, -ENOENT ; check if exists
    je .noent
    test rax, rax ; check for errors
    jnz .error

    mov eax, [STATBUF+28] ; get the entry type
    and eax, 0xF000 ; mask to get type
    cmp eax, 0x4000 ; S_IFDIR
    je .prep_dir
    jmp .file

    .prep_dir:
    mov rdi, rsi
    jmp .dir

    .noent: ; this should create a proper entry (dir/file)
    mov rdi, rsi
    call strlen

    cmp byte [rdi + rax - 1], '/'
    jne .file ; open auto creates the file anyway
    
    mov rax, 83 ; mkdir
    mov rsi, 0o755
    syscall

    test rax, rax
    jnz .error
    ; now we have a directory to copy to :)
    jmp .dir

    .file:
    mov rdi, 1
    call ncmd

    mov rdi, rax
    call copy_file

    test rax, rax
    jnz .error
    ; done copying
    jmp .exit

    .dir:
    xor rcx, rcx ; counter for looping

    mov rsi, rdi ; move base path
    mov rdi, SOURCE_BUFFER
    call strcpy ; copy it to buffer

    call fix_dirname; rdi holds the buffer already

    mov r12, SOURCE_BUFFER
    lea r13, [SOURCE_BUFFER+rax] ; start point to append

    .dir_loop:
    inc rcx
    cmp rcx, [LAST_FILE]
    je .exit ; we're done

    mov rdi, rcx
    call ncmd
    mov rdx, rax ; move arg ptr

    mov rdi, rdx
    call basename ; rax holds ptr to basename of rdx

    mov rsi, rax
    mov rdi, r13
    call strcpy ; append basename to dirname to get new name

    mov rdi, rdx ; source
    mov rsi, r12 ; destination
    call copy_file

    jmp .dir_loop
    
    .error:
    neg rax ; get error
    cmp rax, ENOENT
    je .error_nf

    cmp rax, EACCES
    je .error_perm

    cmp rax, EIO
    je .error_io

    cmp rax, EROFS
    je .error_rofs

    cmp rax, ENOTDIR
    je .error_nodir
    
    cmp rax, EISDIR
    je .error_isdir
    
    jmp .error_unknown

    .error_nf:
    sys_write 2, NOTFOUND_MSG, NFM_LEN
    jmp .exite

    .error_perm:
    sys_write 2, NOPERMISSION_MSG, PM_LEN
    jmp .exite

    .error_io:
    sys_write 2, IOERR_MSG, IOERR_LEN
    jmp .exite

    .error_isdir:
    sys_write 2, ISDIR_MSG, ISDIR_LEN
    jmp .exite

    .error_nodir:
    sys_write 2, NOTDIR_MSG, NOTDIR_LEN
    jmp .exite

    .error_rofs:
    sys_write 2, ROFS_MSG, ROFS_LEN
    jmp .exite

    .error_unknown:
    sys_write 2, UNKNOWN_ERR, UE_LEN
    jmp .exite

    .usage:
    sys_write 2, USAGE, USAGE_LEN

    .exit:
    mov rax, 60
    xor rdi, rdi
    syscall ; exit

    .exite:
    mov rax, 60
    mov rdi, 1
    syscall ; exit with code 1


fix_dirname:
    push rbx
    push rax
    call strlen ; rax holds len of rdi (input)
    mov rbx, rax

    test rbx, rbx
    jz .fixdir_exit

    mov al, [rdi+rbx-1]
    cmp al, '/'
    je .fixdir_exit

    mov byte [rdi+rbx], '/'
    mov byte [rdi+rbx+1], 0
    
    .fixdir_exit:
    pop rax
    pop rbx
    ret

strcpy: ; rsi > rdi (returns about of bytes copied)
    push rcx
    xor rcx, rcx
    
    .strcpy_loop:
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    cmp al, 0
    je .strcpy_done
    inc rcx
    jmp .strcpy_loop
    
    .strcpy_done:
    mov rax, rcx
    pop rcx
    ret

basename: ; rax = basename start pointer
    push rcx
    push rbx
    xor rcx, rcx
    mov rbx, rdi

    .basename_loop:
        mov al, [rdi + rcx] ; get curr byte
        cmp al, 0
        je .basename_done
        cmp al, '/'
        jne .basename_continue
        lea rbx, [rdi + rcx + 1]

        .basename_continue:
        inc rcx
        jmp .basename_loop
        
    .basename_done:
    mov rax, rbx
    pop rbx
    pop rcx
    ret

ncmd: ; takes one arg which is index of the command (arg) and returns a pointer to the command
    push rbp
    push rcx
    push rbx
    push rdi
    mov rbp, rsp
    mov rsp, r15 ; back to start

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
    pop rdi
    pop rbx
    pop rcx
    pop rbp
    ret

lcmd: ; get last arg (rax = arg pointer, rdx = index)
    push rbp
    push rcx
    push rbx
    push rdi
    mov rbp, rsp
    mov rsp, r15 ; back to start

    ; xor rcx, rcx
    mov rcx, 1 ; skip bin name
    mov rbx, [rsp] ; argc

    xor rdx, rdx
    mov rax, -1

    .lcmd_loop:
        inc rcx
        cmp rcx, rbx
        jg .lcmd_done ; return if args are over

        mov rdi, [rsp+rcx*8]

        cmp byte [rdi], '-'
        je .lcmd_loop

        inc rdx
        mov rax, rdi

        jmp .lcmd_loop

    .lcmd_done:

    mov rsp, rbp
    pop rdi
    pop rbx
    pop rcx
    pop rbp
    ret

strlen: ; string to get it's len (no stack usage)
    push rcx
    xor rcx, rcx

    .strlen_loop:
        mov al, [rdi + rcx] ; get curr byte
        cmp al, 0
        je .strlen_done
        inc rcx
        jmp .strlen_loop
        
    .strlen_done:
    mov rax, rcx
    pop rcx
    ret

copy_file: ; source, dest (rdi, rsi)
    push rbp
    push r9
    push r12
    push r13
    push rdi
    push rsi
    push rdx
    push rcx
    mov rbp, rsp

    mov r9, rsi ; save rsi :)
    
    ; open source
    mov rax, 2
    xor rsi, rsi
    xor rdx, rdx
    syscall
    
    cmp rax, 0
    jl .cf_exit; return error if you find one
    mov r12, rax ; save fd
    
    ; open dist
    mov rax, 2
    mov rdi, r9
    mov rsi, 577 ; write | create | truncate
    mov rdx, 0o644
    syscall

    cmp rax, 0
    jl .close_source ; return error if you find one
    mov r13, rax; save fd
    
    .fcopy_loop:
    mov rax, 0 ; read
    mov rdi, r12
    mov rsi, BUFFER
    mov rdx, BUFLEN
    syscall

    cmp rax, 0
    jle .close_dist

    mov rdi, r13
    mov rsi, BUFFER,
    mov rdx, rax
    mov rax, 1 ; write
    syscall

    cmp rax, 0
    jle .close_dist
    jmp .fcopy_loop

    .close_dist:
    push rax
    mov rax, 3
    mov rdi, r13
    syscall
    pop rax

    .close_source:
    push rax
    mov rax, 3
    mov rdi, r12
    syscall
    pop rax
    
    .cf_exit:

    mov rsp, rbp
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop r13
    pop r12
    pop r9
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

