.intel_syntax noprefix
.global _start

.data
	http_response:
	    .ascii "HTTP/1.0 200 OK\r\n\r\n"
	response_len = . - http_response

.bss
	request_buffer: .space 4096
	response_buffer: .space 4096
	path_buffer: .space 256

.text

check_req:
	lea rdi, [request_buffer]
	movzx rdi, byte ptr [rdi]
	cmp dil, 0x47
	je get_req
	jmp post_req

req_file_get:
	lea rdi, [request_buffer]
	lea rcx, [path_buffer]
	mov rdx, 4
	movzx rsi, byte ptr [rdi+rdx]

file_loop_get:
	mov byte ptr [rcx], sil
	inc rdx
	inc rcx
	movzx rsi, byte ptr [rdi+rdx]
	cmp sil, 0x20
	jne file_loop_get
	mov byte ptr [rcx], 0
	ret

req_file_post:
	lea rdi, [request_buffer]
	lea rcx, [path_buffer]
	mov rdx, 5
	movzx rsi, byte ptr [rdi+rdx]

file_loop_post:
	mov byte ptr [rcx], sil
	inc rdx
	inc rcx
	movzx rsi, byte ptr [rdi+rdx]
	cmp sil, 0x20
	jne file_loop_post
	mov byte ptr [rcx], 0
	ret

find_body:
	lea rdi, [request_buffer]
	mov rdx, 5

find_body_loop:
	cmp byte ptr [rdi+rdx], 0x0d
	jne next_byte
	cmp byte ptr [rdi+rdx+1], 0x0a
	jne next_byte
	cmp byte ptr [rdi+rdx+2], 0x0d
	jne next_byte
	cmp byte ptr [rdi+rdx+3], 0x0a
	jne next_byte
	
	add rdx, 4
	sub r8, rdx
	ret

next_byte:
	inc rdx
	jmp find_body_loop

_start:
	mov rdi, 2
	mov rsi, 1
	mov rdx, 0
	mov rax, 41
	syscall
	
	mov r12, rax
	
	push 0
	sub rsp, 8
	mov dword ptr [rsp+4], 0x00000000
	mov word ptr [rsp+2], 0x5000
	mov word ptr [rsp], 2
	
	mov rdi, r12
	mov rsi, rsp
	mov rdx, 16
	mov rax, 49
	syscall
	
	mov rdi, r12
	mov rsi, 0
	mov rax, 50
	syscall

accept_loop:

	mov rdi, r12
	mov rsi, 0
	mov rdx, 0
	mov rax, 43
	syscall
	
	mov r13, rax
	
	mov rax, 57
	syscall
	
	test rax, rax
	jz child
	
	mov rdi, r13
	mov rax, 3
	syscall
	
	jmp accept_loop

child:
	mov rdi, r12
	mov rax, 3
	syscall
	
	mov rdi, r13
	lea rsi, [request_buffer]
	mov rdx, 4096
	mov rax, 0
	syscall
	
	mov r8, rax
	
	jmp check_req

get_req:
	call req_file_get
	
	lea rdi, [path_buffer]
	mov rsi, 0
	mov rdx, 0
	mov rax, 2
	syscall
	
	mov r14, rax
	
	mov rdi, r14
	lea rsi, [response_buffer]
	mov rdx, 4096
	mov rax, 0
	syscall
	
	mov r15, rax
	
	mov rdi, r14
	mov rax, 3
	syscall
	
	mov rdi, r13
	lea rsi, [http_response]
	mov rdx, response_len
	mov rax, 1
	syscall
	
	mov rdi, r13
	lea rsi, [response_buffer]
	mov rdx, r15
	mov rax, 1
	syscall
	
	mov rdi, r13
	mov rax, 3
	syscall
	
	mov rdi, 0
	mov rax, 60
	syscall

post_req:
	call req_file_post
	
	lea rdi, [path_buffer]
	mov rsi, 0x41
	mov rdx, 0777
	mov rax, 2
	syscall
	
	mov r14, rax
	
	call find_body
	
	mov rdi, r14
	lea rsi, [request_buffer]
	add rsi, rdx
	mov rdx, r8
	mov rax, 1
	syscall
	
	mov rdi, r14
	mov rax, 3
	syscall
	
	mov rdi, r13
	lea rsi, [http_response]
	mov rdx, response_len
	mov rax, 1
	syscall
	
	mov rdi, r13
	mov rax, 3
	syscall
	
	mov rdi, 0
	mov rax, 60
	syscall