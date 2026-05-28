# HTTP Server in x86-64 Assembly

A fully functional concurrent HTTP web server written entirely in x86-64 assembly. Handles both GET and POST requests using multi-process concurrency.

![Assembly](https://img.shields.io/badge/Assembly-x86--64-blue)![HTTP](https://img.shields.io/badge/HTTP-1.0-green)![Concurrency|120](https://img.shields.io/badge/Concurrency-fork()-orange)

## Development Process

See [BUILD_LOG.md](BUILD_LOG.md) for detailed step-by-step development notes, including intermediate code versions and debugging insights.

## Features

-  **GET requests** - Serves files from the filesystem
-  **POST requests** - Writes request body to files  
-  **Concurrent connections** - Handles multiple clients via `fork()`
-  **Pure assembly** - Written in pure assembly using only syscalls
-  **~200 lines** - Compact, readable implementation

## Quick Start

```bash
# Build
make

# Run (requires sudo for port 80)
sudo ./server &

# Test GET request
echo "Hello, Assembly!" > /tmp/test.txt
curl http://localhost:80/tmp/test.txt

# Test POST request
curl -X POST -d "test data" http://localhost:80/tmp/output.txt
cat /tmp/output.txt
```

## How It Works

`Client connects`

↓

`accept()`
`returns client fd`

↓

`fork() creates child`

↓

├─` Parent: close client fd, loop back to accept()`

└─ `Child: parse HTTP request`

├─ `GET: open file → read → send contents`

└─ `POST: parse body → open file → write data`

↓

`close client fd, exit`

## Architecture

**Request Parsing:**
- Detects method by checking first byte (`G` vs `P`)
- Extracts file path between first and second space
- For POST: scans for `\r\n\r\n` to locate body

**Concurrency Model:**
- Parent process loops in `accept()`, waiting for connections
- On connection: `fork()` creates dedicated child process
- Child handles request while parent continues accepting
- Each child exits after serving one request

**Syscalls Used:**

`socket` • `bind` • `listen` • `accept` • `fork` • `read` • `write` • `open` • `close` • `exit`

## Implementation Details

**Key Techniques:**
- Manual HTTP parsing (byte-by-byte comparison)
- Stack-based `sockaddr_in` construction
- String scanning for `\r\n\r\n` delimiter
- Network byte order handling (`htons`)

**Challenges Solved:**
- Parsing variable-length HTTP headers in assembly
- Calculating POST body length without `Content-Length` parsing
- Managing multiple file descriptors across fork boundaries
- Zero external dependencies (no libc)

## Code Structure

```assembly
_start:              # Setup socket, bind, listen
accept_loop:         # Accept connections, fork for each
child:               # Handle single request
  check_req:         # GET or POST?
  req_file_*:        # Extract file path
  find_body:         # Locate POST body (if needed)
  # Read/write operations
  # Send HTTP 200 OK
  # Exit
```

## Requirements

- Linux (tested on Ubuntu 24.04)
- x86-64 CPU
- GNU assembler (`as`) and linker (`ld`)
- Root access for port 80

## Technical Specifications

| **Aspect**       | Detail                         |
| ------------ | ------------------------------ |
| **Language**     | x86-64 Assembly (Intel syntax) |
| **Protocol**     | HTTP/1.0                       |
| **Concurrency**  | Multi-process (fork-based)     |
| **I/O Model**    | Blocking                       |
| **Dependencies** | None (pure syscalls)           |

## Examples

```bash
# Serve HTML
cat > /tmp/index.html << EOF
<html><body><h1>Hello from Assembly!</h1></body></html>
EOF
curl http://localhost:80/tmp/index.html

# Write via POST
curl -X POST -d "log entry" http://localhost:80/tmp/server.log

# Concurrent requests (fork in action)
for i in {1..10}; do curl http://localhost:80/etc/hostname & done
```

## Learning Resources

Built following [pwn.college's Building a Web Server](https://pwn.college/computing-101/building-a-web-server/) challenges.

**References:**
- [Beej's Guide to Network Programming](https://beej.us/guide/bgnet/)
- [x64 syscall table](https://x64.syscall.sh)
- [Linux man pages](https://man7.org/linux/man-pages/)

## Limitations

- HTTP/1.0 only (no keep-alive)
- No request validation or error handling
- Single-threaded accept (fork-per-request model)
- Requires **sudo** for privileged port binding
- No HTTPS support

---

**Built to understand low-level networking, HTTP protocol internals, and systems programming from first principles.**

---

## Troubleshooting

### Server Won't Run in Background

```bash
sudo ./server &
[sudo] password for kali:
[1] + suspended (tty input)
```

**Problem:** `sudo` with `&` detaches from terminal but still needs password input, suspending the process.

**Solution:** Use separate terminals:
```bash
# Terminal 1
sudo ./server

# Terminal 2
sudo ./test.sh
```

Or run in foreground then background manually:
```bash
sudo ./server
# Press Ctrl+Z
bg
```

### Server Doesn't Stop

The server runs in an infinite loop waiting for connections (this is intentional). Stop it with:

```bash
# If running in foreground
Ctrl+C

# If running in background
sudo kill -9 <PID>

# Or find and kill by name
pkill -9 server
```

### Permission Denied on Test Files

`rm: cannot remove '/tmp/assembly-post.txt': Operation not permitted`

**Problem:** Server runs as root, so files are owned by root. Regular user can't delete them.

**Solution:** The test script uses `sudo rm` for cleanup. If you still see permission errors, run the test.sh file with sudo permissions or manually clean up:

```bash
sudo rm -f /tmp/assembly-*.txt
```

### Recommended Workflow

**Terminal 1:**
```bash
make run
# Server starts and blocks. Press Ctrl+C to stop.
```

**Terminal 2:**
```bash
make test
# Run tests while server is active
```

This avoids all the background process headaches.
