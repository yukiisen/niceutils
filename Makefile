ASM := nasm
LINKER := ld
SOURCES := $(wildcard *.asm)
OBJECTS := $(SOURCES:.asm=.o)
BINS := $(OBJECTS:.o=)

# Default to release build
.PHONY: build debug clean all

all: build

build: ASM_FLAGS := -f elf64
build: LINK_FLAGS :=
build: $(BINS)

debug: ASM_FLAGS := -f elf64 -g -F dwarf
debug: LINK_FLAGS := -g
debug: $(BINS)

%.o: %.asm
	$(ASM) $(ASM_FLAGS) $<

%: %.o
	$(LINKER) $(LINK_FLAGS) $< -o $@

clean:
	rm -f *.o $(BINS)

