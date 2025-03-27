---
title: "Playing with Unicorn framework [1]"
date: 2024-06-21T06:00:23+06:00
author:
  name: Sk3pper
  # image: /images/author/avatar.png
hero: /images/unicorn-framework-install-workflow.webp
description: A practical guide to setup, use and play with unicorn-engine emulator
theme: Toha

menu:
  sidebar:
    name: Playing with Unicorn framework [1]
    identifier: playing-with-unicorn-framework-1
    parent: reverse-engineering
    weight: 800
---

The main purposes of this article it is to learn **what is unicorn engine**, how to **install** it and understand the **main features**. Recall **general CPU architecture basic concepts** and how **memory is used and organized by the operating system** when a program is running. How to setup a project starting from a skeleton and in the end **real examples to understand APIs and different scenarios where it is possible to use the unicorn engine**.


There will be **two parts** the **first** is more academic, introducing key ideas, and the **second** is more practical, explaining how to setup a project and how to use the emulator with real examples

# 1. Introduction
## 1.1 Introduction to Unicorn
Unicorn is a lightweight, multi-platform, multi-architecture CPU emulator framework, based on [QEMU](https://medium.com/p/7348aa78dae3/edit). It was presented the first time at [Black Hat USA 2015](https://www.youtube.com/watch?v=U8zIToF8wmE&t=2432s) by *Nguyen Anh Quynh and Dang Hoang Vu*.


Unicorn focus on emulate physical CPU (using software only) and on CPU operations only (ignoring machine devices).
With Unicorn it is possible to have different applications:
- [**attack side**] Emulate the code without needing to have a real CPU. For example and attacker can exploit useful functions when he stolen only the binary (in some way).
- [**defense side**] Safely analyze malware code, detect virus signature, reverse shell code, reverse engineering, vulnerability research, and binary analysis.
  
## 1.2 Installing Unicorn
There are two ways to install Unicorn, depending on the language in which we are going to code. Unicorn can be used in **C** or **Python**. In the below a easy flowchart to be more clear to how to install unicorn on Ubuntu system. If you are looking for how to install for other platform visit this two links [1](https://github.com/unicorn-engine/unicorn/blob/master/docs/COMPILE.md), [2](https://www.unicorn-engine.org/docs/).


{{< img src="images/unicorn-framework-install-workflow.webp" align="center" title="Unicorn installation workflow">}}
<br>
As we can see the easiest way to install Python binding is via pip, where packages for all the Operating Systems are provided. It can be useful if we have different projects with virtual environments.


```python
pip install unicorn
```

### 1.3 Unicorn APIs
Unicorn has lot APIs, in the following the most common and useful ones. [Here](https://github.com/kabeor/Unicorn-Engine-Documentation) the official Unicorn CPU emulator framework API documentation. It is written only in Chinese, use a translator or go in my GitHub [repository](https://github.com/Sk3pper/unicorn-engine-skeleton) to read the translated file under *docs* directory.

##### Initialize Unicorn Instance
To initialize the Unicorn class the API `Uc(UC_ARCH, UC_MODE)` is used.
- **UC_ARCH**: hardware architecture type.
- **UC_MODE**: hardware mode type and/or endianness.

There are a lot hardware architecture and hardware mode types and there are many different combinations. The Unicorn Engine Python bindings directory contains [several example scripts](https://github.com/unicorn-engine/unicorn/tree/master/bindings/python).

To start the Unicorn Engine emulating the API `uc.emu_start(begin, until, timeout=0, count=0)` is called. The last argument `count=` can be used to define the number of instructions that are executed before the Unicorn Engine stops executing. If `count=` is zero or less than counting by the Unicorn Engine is disabled. To stop emulating the API `uc.emu_stop()` is used.

##### Use registers R/W
Once the unicorn engine is initialized, registers can be read by calling uc.reg_read(reg_id, opt=None)or written by calling `uc.reg_write(reg_id, value)`. The reg_id is defined in the appropriate architecture constant Python file in the Python bindings directory.
- `ARM-64` in `arm64_const.py`
- `ARM` in `arm_const.py`
- `M68K` in `m68k_const.py`
- `MIPS` in `mips_const.py`
- `SPARC` in `sparc_const.py`
- `X86` in `x86_const.py`

##### Memory Allocation
Memory must be allocated and mapped before to use it. To map memory the APIs `uc.mem_map(address, size, perms=uc.UC_PROT_ALL)` is used. The following memory protections are available: *`UC_PROT_NONE, UC_PROT_READ, UC_PROT_WRITE, UC_PROT_EXEC, UC_PROT_ALL`*. To protect a range of memory the API `uc.mem_protect(address, size, perms=uc.UC_PROT_ALL)` is used. To unmap memory the API `uc.mem_unmap(address, size)` is used.

##### Read/Write into memory
Once the memory is mapped it can be written to by calling `uc.mem_write(address, data)`. To read from the allocated memory `uc.mem_read(address, size)` is used.

##### Hooks
To add a hook the API `mu.hook_add(UC_HOOK_*, callback, user_data, begin, end, ...)`. To delete the hook `emu.hook_del(hook)`. Unicorn supports a wide arrange of hooks.

**`UC_HOOK_CODE`**: It is one of the most useful. Hook is called before every instruction is executed. To translate the instruction capstone library is used.

```python
import capstone

def hook_instr_code(uc, address, size, user_data):
  data = bytes(mu.mem_read(address, size))

  md = capstone.Cs(capstone.UC_ARCH, capstone.UC_MODE)
  md.detail = True

  for i in md.disasm(data, address):
    inst = ("\t%s\t%s" % (i.mnemonic, i.op_str))

  print(f">>>>>>>> Tracing instruction at 0x{address:X}:{inst} | 
         hex: {data.hex()} | size: {size}"

uc.hook_add(UC_HOOK_CODE, hook_code)
```
<br>

**`UC_HOOK_INTR`**: It allows you to **intercept and handle interrupts during emulation**. When an interrupt occurs, the engine invokes the specified callback function. Intercept and handle interrupts (e.g., software interrupts, exceptions, system calls) during emulation.


```python
def handle_interrupt(uc, intno, user_data):
    if intno == 6:  # Example: Handle SIGILL interrupt
        uc.emu_stop()
    elif intno != 0x80: # handle Linux syscall
        print("got interrupt %x ???" %intno);
        return

uc.hook_add(UC_HOOK_INTR, handle_interrupt)
```

## 1.4 Reverse engineering tools
To accurately emulate CPU behavior, we require specialized tools like [Binary Ninja](https://binary.ninja/), [Ghidra](https://ghidra-sre.org/), or other disassemblers and reverse engineering tools. These programs help us to understand the CPU context to properly set registers, memory, and instruction flow. These tools enable us to dissect binary code into human-readable and assembly instructions, which is **key** to help us to **recreating the exact state of the CPU to set it to emulate with unicorn**.

# 2. Recall basic concepts
Before continuing it is necessary to recall some basic principles. The unicorn-engine is a powerful framework **but without the right knowledge it is useless**. In the following two sections we will see the CPU architecture principles about *ARM* and *X86* architectures and how the memory is organized and used when program is running.

## 2.1 CPU architecture principles
### 2.1.1 ARM
***ARM32***: ARM32 refers to the 32-bit ARM architecture. It's also known as ARMv7. It's a RISC (Reduced Instruction Set Computer) architecture that has been widely used in many mobile and embedded devices due to its power efficiency. Key features:
- It uses 32-bit registers.
- It supports a maximum of 4GB of addressable memory.
- It includes optional components such as *Thumb* (a 16-bit instruction set), *Jazelle* (for Java acceleration), and *NEON* (for media and signal processing).

***ARM32 Registers***: ARM32 architecture has a total of 16 registers (R0 to R15). Each register is 32 bits in size. Here's a brief description of each:

- **R0 to R10**: These are general-purpose registers.
- **R11 (FP)**: This is also known as the Frame Pointer. In some conventions, it's used to keep track of the function's stack frame, which is the area on the stack that contains the function's local variables and other information. By using a frame pointer, a function can access its local variables at fixed offsets from the FP, which can simplify code generation. However, not all conventions or compilers use a frame pointer, and some may use R11 as an additional general-purpose register.
- **R12 (IP)**: This is also known as the Intra-Procedure-call scratch register. It's a temporary workspace that a function can use however it wants. The name comes from its use in some conventions: when one function calls another function, it can use R12 to hold temporary data that's needed during the call. However, because the called function is also free to use R12, the original function can't assume that the value of R12 will be preserved after the call.
- **R13 (SP)**: Stack Pointer. It points to the top of the current stack.
- **R14 (LR)**: Link Register. It stores the return address when a subroutine is called.
- **R15 (PC)**: Program Counter. It contains the address of the next instruction to be executed.

***ARM32 Conventions***: ARM32 follows certain conventions for function calling, register usage, and more. Here are some key conventions:
- **Function Calling**: When a function is called, arguments are typically passed in registers R0 to R3. If there are more arguments, they are passed on the stack.
- **Return Value**: The return value of a function is typically passed in register R0.
- **Callee-saved Registers**: Registers R4 to R11 are callee-saved. This means that if a function uses these registers, it must save the original values and restore them before returning. **Callee-saved registers** (AKA **non-volatile** registers, or **call-preserved**) are used to hold long-lived values that should be preserved across calls.
- **Caller-saved Registers**: Registers R0 to R3 and R12 are caller-saved. This means that if a function calls another function, it must save the values of these registers if it wants to use them after the call. **Caller-saved registers** (AKA **volatile** registers, or **call-clobbered**) are used to hold temporary quantities that need not be preserved across calls.

***ARM64***: ARM64, also known as ARMv8-A, is the 64-bit version of the ARM architecture. It's used in many modern mobile devices and servers due to its high performance and power efficiency. Here are some key features:
- It uses 64-bit registers, allowing it to work with larger datasets and address more memory.
- It supports over 18 exabytes of addressable memory.
- It includes new instructions for cryptography and atomic operations.
- It maintains compatibility with 32-bit software.

**ARM64 Registers**: ARM64 architecture has a total of 31 general-purpose registers (X0 to X30). Each register is 64 bits in size. Here's a brief description of each:
- **X0 to X30**: These are general-purpose registers.
- **SP (Stack Pointer)**: It points to the top of the current stack.
- **LR (Link Register, X30)**: It stores the return address when a subroutine is called.
- **PC (Program Counter)**: It contains the address of the next instruction to be executed.

In addition to these, there are also 32 floating-point registers (V0 to V31), which can be used for scalar floating-point, vector, and SIMD operations.

***ARM64 Conventions***: ARM64 follows certain conventions for function calling, register usage, and more. Here are some key conventions:

- **Function Calling**: When a function is called, arguments are typically passed in registers X0 to X7. If there are more arguments, they are passed on the stack.
- **Return Value**: The return value of a function is typically passed in register X0 (and X1 if it's a 128-bit value).
- **Callee-saved Registers**: Registers X19 to X30 are callee-saved. This means that if a function uses these registers, it must save the original values and restore them before returning.
- **Caller-saved Registers**: Registers X0 to X18 are caller-saved. This means that if a function calls another function, it must save the values of these registers if it wants to use them after the call.

>Note that these conventions can vary depending on the specific ARM32 ABI (Application Binary Interface) being used. Always refer to the documentation for your specific environment for the most accurate information.

### 2.1.2 X86
***x86***: It is a complex instruction set computer (**CISC**) architecture that uses a modest number of special-purpose registers instead of large quantities of general-purpose registers.

- **Registers**: The x86 32-bit architecture has 8 general-purpose integer registers (*EAX, EBX, ECX, EDX, ESI, EDI, ESP, and EBP*).
- **Addressing**: The architecture supports 32-bit addressing, allowing it to address up to 4 GB of memory.
- **Instruction Set**: The x86 32-bit architecture has a large instruction set that includes a variety of instructions for arithmetic, logical, and control operations.
- **Compatibility**: The x86 32-bit architecture is backward compatible with the earlier 16-bit architecture, allowing for easy transition from 16-bit to 32-bit applications.

***x86 Registers***: The x86 architecture has **8 general-purpose registers** that can be used for storing and manipulating data. These registers are:
1. **EAX** (Extended Accumulator): Used for arithmetic and logical operations.
2. **EBX** (Extended Base): Used for storing base addresses and other data.
3. **ECX** (Extended Counter): Used as a counter for loops and other operations.
4. **EDX** (Extended Data): Used for storing data and performing I/O operations.
5. **ESI** (Extended Source Index): Used as an index register for memory operations.
6. **EDI** (Extended Destination Index): Used as an index register for memory operations.
7. **ESP** (Extended Stack Pointer): Used to keep track of the stack pointer.
8. **EBP** (Extended Base Pointer): Used as a base pointer for stack operations.

The x86 architecture also has several specialized registers that are used for specific purposes:
- **EIP** (Extended Instruction Pointer): Used to store the current instruction pointer.
- **EFLAGS** (Extended Flags): Used to store the status flags of the CPU.

***x86–64***: also known as x86–64, AMD64, or Intel 64, is a powerful 64-bit instruction set architecture (ISA) widely used in modern personal computers, servers, and workstations. It's a significant advancement over its predecessor, the 32-bit x86 architecture (commonly referred to as i386).

- **64-Bit Addressing**: The most significant change is the ability to address much larger memory spaces. x86_64 supports theoretical addressing of 2⁶⁴ bytes (18.4 quintillion bytes), a massive increase compared to the 4 GB limit of 32-bit architectures. This allows applications to handle larger datasets, complex computations, and memory-intensive tasks more efficiently.
- **General-Purpose Registers**: x86_64 doubles the number of general-purpose registers (from 8 to 16), providing more room for storing temporary data and variables, potentially improving performance in certain scenarios.
- **New Instructions**: The architecture introduced new instructions to support 64-bit operations, floating-point calculations, and other optimizations.
- **Backward Compatibility**: A crucial feature of x86_64 is its backward compatibility with older 32-bit x86 applications. This allows users to run existing software seamlessly alongside 64-bit programs on the same system.


***x86–64 registers***: there are 16 general-purpose 64-bit registers: ***rax, rbx, rcx, rdx, rdi, rsi, rbp, rsp, r8 to r15***. The lower 32-bit, 16-bit, and 8-bit portions of these registers can also be accessed using different naming conventions, e.g. *eax, ax, al*. The registers have the following conventional uses:

- **rax** is used to store function return values
- **rdi, rsi, rdx, rcx, r8, r9** are used to pass the first 6 function arguments
- **rsp** is the stack pointer
- **rbp** is often used to reference local variables
- **rbx, r12-r15** are callee-saved registers that functions should preserve

The x86–64 architecture also includes 16 128-bit SIMD (Streaming SIMD Extensions) registers named **xmm0** to **xmm15**, used for floating-point and vector operations.

## 2.2 Memory organization
{{< img src="images/memory-organization.png" align="center" title="Memory organization">}}
<br>
Each running program has its own memory layout, separated from other programs. The layout consists of a lot of segments, including:

- `stack`: stores local variables
- `heap`: dynamic memory for programmer to allocate
- `data`: stores global variables, separated into initialized and uninitialized
- `text`: stores the code being executed


**Stack**. As shown above, the stack segment is near the top of memory with high address. Every time a function is called, the machine allocates some stack memory for it. When a new local variables is declared, more stack memory is allocated for that function to store the variable. Such allocations make the stack grow downwards. After the function returns, the stack memory of this function is deallocated, which means all local variables become invalid. The allocation and deallocation for stack memory is automatically done. The variables allocated on the stack are called stack variables, or automatic variables.

**Heap**. In the previous section we saw that functions cannot return pointers of stack variables. To solve this issue, you can either return by copy, or put the value at somewhere more permanent than stack memory. Heap memory is such a place. Unlike stack memory, heap memory is allocated explicitly by programmers and it won't be deallocated until it is explicitly freed.

> In the next section, we will look at how to set up a project and some practical examples of emulating code in various contexts.

# Resources
##### Unicorn
- Unicorn slides presentation | https://www.unicorn-engine.org/BHUSA2015-unicorn.pdf
- Unicorn video presentation |https://www.youtube.com/watch?v=U8zIToF8wmE
- Unicorn Emulator-Install Unicorn and Run Example Code | https://www.youtube.com/watch?v=AsbWDH4Kfls
- Installation guide | https://github.com/unicorn-engine/unicorn/blob/master/docs/COMPILE.md
- Unicorn docs | https://www.unicorn-engine.org/docs/
- Unicorn Engine Notes | https://github.com/alexander-hanel/unicorn-engine-notes
- Unicorn FAQ | https://github-wiki-see.page/m/unicorn-engine/unicorn/wiki/FAQ
- Official Unicorn CPU emulator framework API documentation | https://github.com/kabeor/Unicorn-Engine-Documentation
- Unicorn Engine Reference (Unofficial) | https://hackmd.io/@K-atc/rJTUtGwuW?type=view
- Grumpy Unicorn | https://carstein.github.io/2019/01/08/grumpy-unicorn.html
- Unicorn Engine Introduction | https://ctf-wiki.mahaloz.re/reverse/unicorn/introduction/

##### Recall basic concepts
- CPU architecture
- x86 Assembly Guide | https://www.cs.virginia.edu/~evans/cs216/guides/x86.html
- Overview of ARM64 Architecture and Instruction Sets | https://www.youtube.com/watch?v=95SceqrO_TU&t=511s
- ARM Architecture - Registers and Exception Model | https://www.embien.com/blog/arm-architecture-registers-exception-model
- ARM Program Status Registers | https://s-o-c.org/arm-program-status-registers/
- Azeria Lab Tutorials | https://azeria-labs.com/writing-arm-assembly-part-1/
- ARM architecture family | https://en.wikipedia.org/wiki/ARM_architecture_family#Registers
- Arm programming quick reference | https://community.arm.com/arm-community-blogs/b/operating-systems-blog/posts/arm-neon-programming-quick-reference

##### Memory
- Stack vs Heap Memory | https://www.guru99.com/stack-vs-heap.html
- Stack and Heap Memory | https://courses.engr.illinois.edu/cs225/fa2022/resources/stack-heap/
- Stack vs Heap understanding memory allocation in programming | https://medium.com/huawei-developers/stack-vs-heap-understanding-memory-allocation-in-programming-a83a54901416