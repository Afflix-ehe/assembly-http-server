#assembly #x86-64 #http-server #systems-programming #networking

This document logs my journey building an HTTP server in x86-64 assembly from scratch, starting with a simple exit program and progressing through each networking primitive.

---

## Starting from the very basics...

**Goal -** By the end of this, I hope to have built a fully functioning concurrent `HTTP` web server in `intel x86_64` assembly that supports `GET` and `POST` functionality.

### Resources used

Throughout the course of this learning exercise, I've used the levels in [pwn.college's Building A Web Server dojo](https://pwn.college/computing-101/building-a-web-server/) as a guideline for the steps I've broken down this enormous task into, as well as their [youtube playlist](https://www.youtube.com/watch?v=4S78xEhxh7k&list=PL-ymxv0nOtqqYlFBiJ_gMff9zHfHMNCtG) on the same for a brief overview on the concepts before jumping in.

[Beej's Guide to Network Programming](https://www.beej.us/guide/bgnet/html/split-wide/index.html) was also a really helpful read in that respect - comprehensive in exchange for being a longer read lol.

Aside from that, I've used the [x64 syscall table](x64.syscall.sh), and the [Linux manual pages](https://man7.org/linux/man-pages/index.html) to reference all the syscalls I've used.

---

**_UPDATE -_** I'm glad to say I achieved what I set out to do! Below is my entire building process documented as I went through with everything.

---

### Build Process

Starting from the very basics, I wrote the barebones code of a simple program whose only purpose is to `exit` cleanly.

```assembly
.intel_syntax noprefix
.global _start

_start:
    mov rax, 60
    syscall
```

Moving on, I used the `socket` syscall `41` to create a socket `fd`. This was a fun experience about learning how everything in Unix *is* really a file descriptor.

I used commands like `grep -r AF_INET /usr/include` to look for the integer equivalents for the arguments I wanted to pass to the syscall. the final syscall for socket was equivalent to `socket(AF_INET, SOCK_STREAM, 0)`

```assembly
.intel_syntax noprefix
.global _start

_start:
    mov rdi, 2
    mov rsi, 1
    mov rdx, 0
    mov rax, 41
    syscall

    mov rdi, 0
    mov rax, 60
    syscall
```

Next step was obviously to *bind* this socket that I just created to a specific IP address and port number using the `bind` syscall `49`. For the sake of brevity, I read up on the syscall's nuances on its manpage and more about the `sockaddr_in` struct on the `ip` manpage. 

The structure of `sockaddr_in`, which is the 2nd argument to the `bind` syscall is a 16 byte struct that contains info like the type/family of the socket (2 bytes) and 14 bytes for the rest of its contents. For my case of a TCP/IP connection, my `sockaddr_in` was essentially- 

```c
struct sockaddr_in {
	uint16_t sin_family;  # 2 bytes
	uint16_t sin_port;    # 2 bytes
	uint32_t sin_addr;    # 4 bytes
	uint8_t __pad[8];     # 8 bytes of padding
}
```

The 8 bytes of padding is because the entire `sa_data` section after the family part is of 14 bytes total. I built this on the stack and passed the stack pointer into `rsi` for the 2nd argument.

So my final syscall looked something like -

`bind(3, {sa_family=AF_INET, sin_port=htons(80), sin_addr=inet_addr("0.0.0.0")}, 16)`

```assembly
.intel_syntax noprefix
.global _start

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

    mov rdi, 0
    mov rax, 60
    syscall
```

With the socket ready, I ran the `listen` syscall `50` to make it start listening for incoming connections passively. 

```assembly
.intel_syntax noprefix
.global _start

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

    mov rdi, 0
    mov rax, 60
    syscall
```

After the socket has started listening, I used the `accept` syscall `43` to accept the first incoming connection (which in my case is the only connection request as my backlog is set to 0).

```assembly
.intel_syntax noprefix
.global _start

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

    mov rdi, r12
    mov rsi, 0
    mov rdx, 0
    mov rax, 43
    syscall

    mov rdi, 0
    mov rax, 60
    syscall
```

Now that I have a working connection, the first step in interaction was to make a static server that reads the request, completely ignores anything being said (lol), and just responds with ["HTTP/1.0 200 OK\r\n\r\n"] - promptly closing the connection and exiting afterwards.

```assembly
.intel_syntax noprefix
.global _start

.data
    http_response:
        .ascii "HTTP/1.0 200 OK\r\n\r\n"
    response_len = . - http_response

.bss
    request_buffer: .space 4096

.text

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

    mov rdi, r12
    mov rsi, 0
    mov rdx, 0
    mov rax, 43
    syscall

    mov r13, rax

    mov rdi, r13
    lea rsi, [request_buffer]
    mov rdx, 4096
    mov rax, 0
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
```

To move away from a static server, the first step was to create a server handling GET requests. I used the `read` syscall to read the incoming request and parse through it to get what's being asked, `open` to open the requested file and `read` its contents, and finally `write` the requested content back to the connection before `closing it`.

I found the requested file path by examining the URL, starting from the 4th index since "GET " is 4 characters and the file path would be between the 1st and the 2nd spaces. So by starting from the first character after the space and reading until I encounter the next space, I can determine the length of the requested file path, read it into the path buffer, and use that to open the file and process it accordingly.

```assembly
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

    mov rdi, r12
    mov rsi, 0
    mov rdx, 0
    mov rax, 43
    syscall

    mov r13, rax

    mov rdi, r13
    lea rsi, [request_buffer]
    mov rdx, 4096
    mov rax, 0
    syscall

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
```

Now that I have created a dynamically responding server, I wanted to introduce concurrency in handling multiple requests.

I did this using the `fork` syscall which creates a duplicate of the running server program, checks whether the program is the `parent` or the `child`, closes the connection immediately if its the `parent` and accepts the next connection request - or closes the listening socket if its the `child` and processes and the request.

```assembly
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
```

Finally, I took somewhat of a leap with this, but since I already had a Concurrent `GET` server, I modified its code to now also handle `POST` requests as well, and thus - ***finally*** - achieve my initial goal of building a web server that concurrently handles both `GET` and `POST` requests.

Since `GET` and `POST` are the only 2 requests I've decided to handle, I check the initial character of the request and depending on whether it's a `G` or a `P`, handle the request accordingly.

For `POST` requests, getting the file path was the same, but getting the actual body was a bit tricky. For that, I literally just compared every 4 consecutive bytes iteratively in a loop until I find the `\r\n\r\n` string, because I know the body will start after that.

Finally, this is the completed code for the entire web server - 

```assembly
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
```