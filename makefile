# Makefile for assembly HTTP server

ASM = as
LD = ld
TARGET = server
SRC = server.s

all: $(TARGET)

$(TARGET): $(SRC)
	$(ASM) $(SRC) -o server.o
	$(LD) server.o -o $(TARGET)

clean:
	rm -f server.o $(TARGET)

run: $(TARGET)
	@echo "Starting server on port 80 (requires sudo)..."
	sudo ./$(TARGET)

test: $(TARGET)
	@echo "Running tests..."
	sudo ./test.sh

kill: $(SERVER)
	sudo pkill server

.PHONY: all clean run test