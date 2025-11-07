import re
import subprocess

# refs:
# - https://nathanotterness.com/2021/10/tiny_elf_modernized.html
# - https://en.wikipedia.org/wiki/Executable_and_Linkable_Format#ELF_header

# ARM machine code is surprisingly hard to write by hand
# which makes sense and we don't want to build an assembler anyway.
def assemble(assembly_file: str, object_file: str = "temp.o") -> bytes:
    # assemble the source file
    assemble_cmd = ["as", "-o", object_file, "-al", "-mlittle-endian", "-march=armv8-a"]
    _ = subprocess.run(assemble_cmd, check=True, capture_output=True, input=assembly_file.encode())

    # get the section offset
    objdump_output = subprocess.check_output(["objdump", "-h", object_file], text=True)
    match = re.search(r"^\s*\d+\s+\.text\s+([0-9a-fA-F]+)\s+[0-9a-fA-F]+\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)", objdump_output, re.MULTILINE)
    assert match is not None, "can't find .text section"

    # extract .text
    size = int(match.group(1), 16)
    offset = int(match.group(2), 16)

    with open(object_file, "rb") as f:
        _ = f.seek(offset)
        text = f.read(size)

    # os.remove(object_file)
    return text

def db(x: int): return x.to_bytes(1, "little")
def dd(x: int): return x.to_bytes(2, "little")
def dw(x: int): return x.to_bytes(4, "little")
def dq(x: int): return x.to_bytes(8, "little")

address_start_va = 0x40_00_00_00

# offset: 0
hdr = [
    db(0x7F), b'E', b'L', b'F', # EI_MAG0-EI_MAG3
    db(2),                      # EI_CLASS: 64-bit
    db(1),                      # EI_DATA: little endian
    db(1),                      # EI_VERSION: elf version 1
    db(0),                      # EI_OSABI: ABI version
    dq(0),                      # EI_ABIVERSION+EI_PAD: ABI version + padding

    dd(2),    # e_type: executable
    dd(0xb7), # e_machine: Arm 64-bits (Armv8/AArch64)
    dw(1),    # e_version: 1

    dq(address_start_va+0x40+0x38),    # e_entry: address of entry point
    dq(0x40), # e_phoff: address of program header table
    dq(0),    # e_shoff: address of section header table - empty: we don't use it yet.
    dw(0),    # e_flags: not used

    dd(0x40), # e_ehsize: header sz
    dd(0x38), # e_phentsize: program header entry sz
    dd(1),    # e_phnum: num of program header entries
    dd(0x40), # e_shentsize: section header entry sz
    dd(0),   # e_shnum: num of section header entries
    dd(0),   # e_shstrndx: section header names
]

# offset: 0x78
text = assemble(
# write(1, "hello world!\n", 13)
'''
mov x3, #0x40000000
add x3, x3, #0xa0
mov x0, #0x1
mov x1, x3
mov x2, #0xd
mov x8, #0x40
svc #0x0
''' +

# exit(0)
'''mov x8, #0x5d
mov x0, #0x0
svc #0x0
''')+b"hello world!\n"

# offset: 0x40
prog_hdr =  [
    # first entry
    dw(1), # PT_LOAD
    dw(0b101), # PF_X | PF_R
    dq(0), # p_offset -- todo: what's the purpose of this one?
    dq(address_start_va), # p_vaddr
    dq(address_start_va), # p_addr
    dq(0x40+0x38+len(text)), # p_filesz
    dq(0x40+0x38+len(text)), # p_memsz
    dw(0), # p_flags
    dw(0x2000) # p_align -- todo: what's this?
]

# out = hdr + prog_hdr + txt
def combine(x: list[bytes]): return b''.join(x)

assert len(combine(hdr)) == 0x40, f"invalid elf header len={len(hdr)} (expected {0x40})"
assert len(combine(prog_hdr)) == 0x38, f"invalid program section header len={len(prog_hdr)} (expected {0x38})"

out_bin = combine(hdr + prog_hdr + [text])

with open("out", "wb") as out_fd:
     _ = out_fd.write(out_bin)
