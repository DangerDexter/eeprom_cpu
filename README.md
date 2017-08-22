# An 8-bit CPU with Few Chips

## Warren Toomey, © 2017, GPL3

# Introduction: 22nd August 2017

I stumbled across
[Ben Eater’s video series on building a working CPU](https://eater.net/8bit/)
on a breadboard. I had already built some CPUs in the
[Logisim simulator](http://minnie.tuhs.org/CompArch/Tutes/week03.html) and on
[an FPGA](http://minnie.tuhs.org/Programs/UcodeCPU/index.html),
but I hadn’t actually done the wiring by hand.
I felt constrained by the memory limitations of this Simple As Possible (SAP) CPU, so I decided to design an 8-bit CPU with more instructions and with a larger address space. At the same time, I wondered how few chips I could get away with in the design. Right now, the CPU is about 30 chips, not including any I/O or
clock circuitry. Here is a quick run-down of the design.

My CPU is an 8-bit CPU with a 16-bit address space. There are 64 instructions
and eight ALU operations. There are two user-visible register, the A register
and the B register. Instructions are 1-byte, 2-bytes or 3-bytes in size:

+ the first byte encodes the instruction, although only the first 64
  values are legal instructions. Single byte instructions operate on
  the registers, e.g. ADDA performs A= A + B
+ two-byte instructions have a constant in the second byte, e.g.
  LCA 23 loads the constant 23 into the A register
+ three byte instructions have a memory address stored in the second and
  third bytes, e.g. JMP 0x2000 jumps to the location 0x2000. Addresses
  are stored big-endian, i.e. the high byte is stored first in memory.

The two operands for the 8-bit ALU are the A and B registers. The least
significant three bits in each instruction encode the ALU operation. The ALU
operation is not used in every instruction. Here is the list of ALU operations.

| Operation | 	   ALU Output 		|
|:---------:|:-------------------------:|
| ADD       | A + B                     |
| SUB       | A - B                     |
| AND       | A & B                     |
| OR        | A or B                    |
| XOR       | A ^ B                     |
| A         | A                         |
| B         | B                         |
| INCB      | B+1                       |

As well as an 8-bit output, the ALU produces four flags: zero, negative,
overflow and carry (NZVC). The overflow and carry flags are only generated
on the ADD and SUB operations.

For three-byte instructions, the address in the instruction is stored
in the memory address register (MAR) before the actual work is done.

Here is the current list of instructions:

| Instruction | Action 		|
|:-----------:|:---------------:|
| ADDA	| A= A + B              |
| SUBA	| A= A - B              |
| ANDA	| A= A & B              |
| ORA	| A= A or B             |
| XORA	| A= A ^ B              |
| JMP   | PC= MAR               |
| TBA	| A= B                  |
| INCB	| B++                   |
| ADDB	| B= A + B              |
| SUBB	| B= A - B              |
| ANDB	| B= A & B              |
| ORB	| B= A | B              |
| XORB	| B= A ^ B              |
| TAB	| B= A                  |
| LCA   | Load constant into A  |
| LCB   | Load constant into B  |
| LMA   | A = mem[MAR]          |
| LMB   | B = mem[MAR]          |
| SMA	| mem[MAR]= A           |
| SMB	| mem[MAR]= B           |
| TTOA	| Send A to the terminal |
| TTOB	| Send B to the terminal |
| TTIA	| Read A from the terminal |
| TTIB	| Read B from the terminal |
| JLT	| PC= MAR if N set       |
| JEQ	| PC= MAR if Z set       |
| JNE	| PC= MAR if Z clear     |
| JGE	| PC= MAR if N clear     |
| JLE	| PC= MAR if either Z or N are set |
| JGT	| PC= MAR if both Z and N are clear |
| JCS	| PC= MAR if C set       |
| JVS   | PC= MAR if V set       |
| JVC   | PC= MAR if V clear     |
| JCC   | PC= MAR if C clear     |
| LIA	| A= mem[MAR+B]          |
| SIA	| mem[MAR+B]= A          |
| INCM	| mem[MAR]++             |
| SUB	| A - B, just to set the flags |

# Top-level design


![main design](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/main.png)

Above is the top-level design of the CPU. I’m only showing the data bus in the diagram. There is a 32K x 8 ROM and a 32K x 8 RAM, both connected to the horizontal data bus. The data bus is connected to the Instruction Register (IR), a high and low Memory Access Register (MAR), the A register and the B register.

The output from the ALU is connected through a tri-state buffer back to the data bus. This allows the ALU to write its result back to RAM and into the A and B registers.

I haven’t shown the control logic or the control signals yet; these will be covered below.

# Designing the ALU

I wanted my CPU to have a reasonable set of ALU operations. At first I thought I could use a couple of 74LS181 4-bit ALUs. However, they are no longer made, and I couldn’t find any other 4-bit or 8-bit ALUs. So I had to design my own.

A proper ALU with several operations is going to be expensive chip-wise if I built it using the available 7400 series ICs. Then I came across Dieter Mueller’s articles on
[designing an ALU using EEPROMs](http://6502.org/users/dieter/).

Of course! An ALU is just a combinatorial circuit that takes input bits and produces output bits. That’s also what an EEPROM does.

My design needs an ALU that takes two 8-bit inputs plus three bits for the ALU operation, and it produces twelve bits of output: an 8-bit result and another four bits for the ALU flags: negative, zero, overflow and carry (NZVC). 

I’ve chosen to implement this using two EEPROMs. Each one acts as a 4-bit ALU: it produces a 4-bit output as well as the NZVC flags. Each ALU takes two 4-bit inputs and a 3-bit ALU operation. It also needs the negative and carry flags from a “lower” ALU, so that two 4-bit ALUs can be cascaded to create a single 8-bit ALU. This means that each ALU takes thirteen bits of input: in other words, I can implement each ALU with an 8K x 8 EEPROM. 

Below is the current ALU design as implemented in Logisim.

![ALU](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/alu.png)

The ALU operation and the two operands come in from the left: Arg1 and Arg2. These are split into 4-bit low and high nibbles, and these nibbles are distributed to the two ALUs. The ROMs look up and output the 4-bit results and the four flag values. The Z and C flags from the lower ALU are cascaded up as inputs to the higher ALU. The low and high ALU results are combined, and the top NZVC flags are stored in a 4-bit register.

As the EEPROM is programmable, any set of eight operations on two 4-bit inputs can be programmed into the EEPROM.

# The PC and Address Logic

![PC logic](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/pclogic.png)

Above is the PC and address logic as implemented in Logisim. One of three
address values can be placed on the address bus, which runs vertically in the
diagram from the multiplexer down to the ROM and RAM. The address value can be:

+ the program counter
+ the value of the 16-bit memory address register (MAR)
+ the value of the 16-bit memory address register (MAR) with the B value added in. This allows indexed addressing to be done.

The PC is implemented as a presettable 16-bit counter. When the PCincr
control line is enabled, the PC's value increments. When the PCload
control line is enabled, the PC loads the value from the address bus: this
is used in the jump instructions.

# The Control Logic

![Control logic](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/control1.png)

If you look at the design so far, there is very little combinatorial logic.
We now need some logic to control all of this. We need these control lines (as shown in the above diagram):

+ Clk: the clock that goes to all sequential circuits
+ PCload: load a new value from the address bus into the PC
+ PCincr: get the PC to increment to the next address
+ RAMwrite: write the value on the data bus into RAM
+ IRload: load the instruction register from the data bus
+ HMload: load the high byte of the Memory Address Register from the data bus
+ LMload: load the low byte of the Memory Address Register from the data bus
+ Aload: load the A register from the data bus
+ Bload: load the B register from the data bus
+ ALUwrite: place the ALU's output onto the data bus
+ MEMdisa: disable the RAM and ROM, so that the ALU output can be sent to either the A or B registers
+ FlagWr: latch the NZCV flags from the ALU. This allows these to be set in one instruction, e.g. a subtraction, and then tested in a second instruction, e.g. a jump if negative instruction.
+ MAMux (2 bits): Choose either the PC, the MAR, or MAR+B as the address to be placed on the address bus.

We have to enable and disable all of these in some sequence in order to perform each CPU instruction. One way to build this logic would be to hard-wire a bunch of logic gates, but this would  violate my design goal of a minimal number of chips.

Instead, I’ve implemented my control logic with some EEPROMs as shown below.

![Control logic](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/control2.png)

There is a 3-bit counter that produces eight phases in each instruction. The phase, plus the current instruction opcode and the value of the NZVC flags go into the two EEPROMs. These look up the appropriate control line values for this opcode/phase/NZVC combination.

The file `control_logic` holds the list of control lines that are enabled
or disabled on each phase of each instructions.

One control line, PhaseRst, actually resets the instruction phase back to zero.
Not all instructions need all eight phases to do the instruction. Rather than
waste time, each instruction can reset the phase to zero and start the next
instruction.

# Status of the CPU: 22nd August 2017

I haven't written the rest of the document yet, so don't read the stuff
below.

Here is what I’ve got to so far. I’ve written a Perl script to read in a program in (my own) assembly language and convert this to the binary instructions. The script outputs the code in a format that Logisim can load into a simulated ROM chip. The script also simulates the assembly program: this was useful to confirm that things worked.

I also have a working Logisim version of the CPU. I’ve written Perl scripts to generate the contents of the EEPROMs in the ALU and the EEPROMs in the control logic. I’ve been able to run a program to calculate the Fibonacci numbers from 2 up to 0xe9 (233).

Here is my estimate of the chips I need to build this.

|             Component                       |      Chip          |
|:--------------------------------------------|:------------------:|
| four 4-bit counters (PC)                    | CD74HC161E         |
| one 2-to-4 decoder (address mux)            | 74HC139            |
| six tri-state bus drivers (address mux)     | 74HC244            |
| one main ROM (memory)                       | AT28C64B-15PU      |
| one main static RAM (memory)                | A623308A-70SF      |
| one AND chip with 4 AND gates (addressing)  | 74HC08             |
| one inverter chip with 6 inverters (ditto)  | SN74HC04NE4        |
| five 8-bit registers (IR, LMAR, HMAR, A, B) | CD74HC273E         |
| one UART                                    | UM245R             |
| two tri-state bus drivers (UART, ALU)       | 74HC244            |
| two ROMs (ALU)                              | AT28C64B-15PU      |
| one 4-bit counter/register (ALU)            | CD74HC161E         |
| four 4-bit adders (indexing)                | CD74HC283E         |
| two ROMs (control)                          | AT28C64B-15PU      |
| one 4-bit counter (control)                 | CD74HC161E         |
| one 556 (clock)                             | NE556AN            |
| one OR gate (clock)                         | 74HC32             |

 
I will need some other components:

+ a pot for the 555 circuit, a toggle button and a pushbutton to control the clock signal
+ several breadboards
+ some tinned wire
+ several LEDs for showing individual lines
+ caps for the 555 circuit

Here is a short video of the CPU in Logisim calculating the Fibonacci
series (version 1 of the CPU):

![running Fibonacci](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/fibonacci_run.gif)

Next tasks:
+ order the components to build it (in progress)
+ wire it up and test each section
+ get the whole computer to work
+ write a compiler to target the instruction set (in progress)
