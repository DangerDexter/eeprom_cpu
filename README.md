# An 8-bit CPU with Few Chips

## Warren Toomey, © 2017, GPL3

# Introduction: 8th August 2017

I stumbled across
[Ben Eater’s video series on building a working CPU](https://eater.net/8bit/)
on a breadboard. I had already built some CPUs in the
[Logisim simulator](http://minnie.tuhs.org/CompArch/Tutes/week03.html) and on
[an FPGA](http://minnie.tuhs.org/Programs/UcodeCPU/index.html),
but I hadn’t actually done the wiring by hand.
I felt constrained by the memory limitations of this Simple As Possible (SAP) CPU, so I decided to design an 8-bit CPU with more instructions and with a larger address space. At the same time, I wondered how few chips I could get away with in the design. Right now, I’m down around 19 chips (on paper) for the CPU proper, not including any I/O or clock circuitry. Here is a quick run-down of the design.

My CPU is an 8-bit CPU with a 12-bit address space. There are sixteen opcodes, of which eight of them are ALU operations. There is only one user-visible register, the A register. Each instruction is 16 bits (two bytes) in size:

+ the top four bits encode the sixteen opcodes
+ the remaining 12 bits encode a memory address

Here is the list of op-codes at present:

| Mnemonic | 	   Action 		|
|:--------:|:--------------------------:|
| ADD addr | mem[address] += A		|
| SUB addr | mem[address] -= A		|
| AND addr | mem[address] &= A		|
| OR addr  | mem[address] |= A		|
| XOR addr | mem[address] ^= A		|
| INC addr | mem[address] += 1		|
| DEC addr | mem[address] -= 1		|
| STO addr | mem[address] = A		|
| LD addr  | A= mem[address]		|
| JMP addr | PC= address always		|
| JZ addr  | PC= address if zero	|
| JNE addr | PC= address if negative	|
| JC addr  | PC= address if carry	|
| JV addr  | PC= address if overflow	|
| SHO	   | Display the A register	|
| HLT	   | Halt CPU			|

The SHO instruction latches the value in the A register into a two-digit hex display, and this is the only output device at present. The HLT instruction really only works in the simulator at present; in the breadboard build I would expect to have to do a JMP to the same instruction (an infinite loop).

# The Top-level Design

![main design](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/main.png)

Above is the top-level design of the CPU. I’m only showing the data paths in the diagram. There is a 2K x 8 ROM and a 2K x 8 RAM, both connected to the horizontal data bus. The data bus is connected to the Instruction Register (IR), a Memory Access Register (MAR), the A register and as one input to the ALU.

The value in the IR is split in half. The top half of the IR is the 4-bit instruction opcode. The lower four bits is combined with the MAR value to be the 12-bit address used to access memory: the IRMAR value.

The output from the ALU is connected through a tri-state buffer back to the data bus. This allows the ALU to write its result back to RAM.

The only output is a register called Ashow which latches the value in the A register on a SHO instruction. This value is displayed in hex on two 7-segment LEDs.

In the top-left is the PC logic. This chooses either the Program Counter (PC)’s value or the IRMAR value as the address to the RAM and ROM. The top address bit selects either the RAM (value 1) or the ROM (value 0). The PC logic contains the PC itself, a muxer and a counter to increment the PC’s value.

I haven’t shown the control logic or the control signals yet; these will be covered below.

# Designing the ALU

I wanted my CPU to have a reasonable set of ALU operations. At first I thought I could use a couple of 74LS181 4-bit ALU. However, they are no longer made, and I couldn’t find any other 4-bit or 8-bit ALUs. So I had to design my own.

A proper ALU with several operations is going to be expensive chip-wise if I built it using the available 7400 series ICs. Then I came across Dieter Mueller’s articles on
[designing an ALU using EEPROMs](http://6502.org/users/dieter/).

Of course! An ALU is just a combinatorial circuit that takes input bits and produces output bits. That’s also what an EEPROM does.

My design needs an ALU that takes two 8-bit inputs plus three bits for the ALU operation, and it produces twelve bits of output: an 8-bit result and another four bits for the ALU flags: negative, zero, overflow and carry (NZVC). 

I’ve chosen to implement this using two EEPROMs. Each one acts as a 4-bit ALU: it produces a 4-bit output as well as the NZVC flags. Each ALU takes two 4-bit inputs and a 3-bit ALU operation. It also needs the negative and carry flags from a “lower” ALU, so that two 4-bit ALUs can be cascaded to create a single 8-bit ALU. This means that each ALU takes thirteen bits of input: in other words, I can implement each ALU with an 8K x 8 EEPROM. 

Below is the current ALU design as implemented in Logisim.

![ALU](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/alu.png)

The ALU operation and the two operands come in from the left: Arg1 and Arg2. These are split into 4-bit low and high nibbles, and these nibbles are distributed to the two ALUs. The ROMs looks up and outputs the 4-bit results and the four flag values. The Z and C flags from the lower ALU are cascaded up as inputs to the higher ALU. The low and high ALU results are combined are stored in an 8-bit register. The top NZVC flags are stored in a 4-bit register.

The ALU operations are:

1. Arg1 + Arg2
2. Arg1 – Arg2
3. Arg1 AND Arg2
4. Arg1 OR Arg2
5. Arg1 XOR Arg2
6. Arg1 + 1
7. Arg1 – 1
8. Arg2

The Arg1 input is wired to the data bus, and the Arg2 input is wired to the A register, so the last operation allows the A register to be written out through the ALU, and eventually over the data bus and back to memory. The STO instruction is implemented using this ALU operation.

As the EEPROM is programmable, any set of eight operations on two 4-bit inputs can be programmed into the EEPROM.

# The PC Logic

![PC logic](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/pclogic.png)

Above is the PC logic as implemented in Logisim. The multiplexer passes either the PC value or the IRMAR value out to the ROM and RAM, controlled by the PCctrl control line. The adder increments the PC’s value based on the PCload control line.

There is one gotcha. When we do JMP address, the IRMAR address needs to be stored into the PC. However, the adder will add 1 to this value. Therefore, the assembler need to store address-1 in the instruction to circumvent the +1 in the PC logic.

As the data path here is 12-bits, I thought I would need to use an 8-bit register and a 4-bit register for the PC, three 4-bit adder chips and three 4-bit multiplexer chips. That would be eight chips! However, I think I can use three 74LS163 counters for a combination adder/register; this would cut the PC logic down to six chips.

# The Control Logic

If you look at the design so far, there is very little combinatorial logic: a tri-state buffer, one inverter gate, the two EEPROMs in the ALU and three mux chips in the PC logic. Now we need some serious logic to control all of this. We need these control lines:

+ Clk: the clock that goes to all sequential circuits
+ PCctrl: send either the PC or the IRMAR value to the RAM/ROM 
+ PCload: load a new value into the PC
+ IRload: load the instruction register from the data bus
+ MARload: load the Memory Address Register from the data bus
+ Aload: load the A register from the data bus
+ FlagWr: store the ALU output and the flags in the two registers in the ALU
+ RAMwrite: write the ALU’s value on the data bus into RAM
+ SHOload: load the Ashow register when we do the SHO instruction
+ ALUop (3 bits): The ALU operation to be performed

We have to enable and disable all of these in some sequence in order to perform each CPU instruction. One way to build this logic would be to hard-wire a bunch of logic gates, but this would  violate my design goal of a minimal number of chips.

Instead, I’ve implemented my control logic with some EEPROMs as shown below.

![Control logic](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/control.png)

There is a 2-bit counter that produces four phases in each instruction. The phase, plus the current instruction opcode and the value of the NZVC flags go into the two EEPROMs. These look up the appropriate control line values for this opcode/phase/NZVC combination.

The four phases are:

+ Phase 0: load the IR register. We enable IRload to load the IR from the data bus, and we enable PCload to increment the PC.
+ Phase 1: load the MAR register. We enable MARload to load the MAR from the data bus, and we enable PCload to increment the PC.
+ Phase 2: perform the ALU operation. Typically, PCctrl is set to 1 to send the IRMAR value to the RAM. The data bus now holds a data value from RAM which goes into the ALU. The A register also goes into the ALU, and the ALUop tells the ALU what to do. FlagWr is enabled to latch the ALU’s output and the flag bits. We can’t write the ALU value to RAM yet, because we are already using the data bus to fetch a value from the RAM!
+ Phase 3: Write the latched ALU value back to RAM: RAMwrite is enabled, and Pcctrl is still keeping IRMAR as the address to the RAM. Alternatively, we are doing one of the “jump” instructions. If the jump instruction matches up with one of the NZVC flags, set PCctrl to 1 and set PCload to 1, so that the PC is loaded from the IRMAR value.

There are only ten input bits to the two EEPROMs: four opcode bits, four NZVC bits and two phase bits. Unforunately, we need more that eight bits of output; that’s why there are two 1K x 8 EEPROMs.

# Status of the CPU: 8th August 2017

Here is what I’ve got to so far. I’ve written a Perl script to read in a program in (my own) assembly language and convert this to the binary instructions. The script outputs the code in a format that Logisim can load into a simulated ROM chip. The script also simulates the assembly program: this was useful to confirm that things worked.

I also have a working Logisim version of the CPU. I’ve written Perl scripts to generate the contents of the EEPROMs in the ALU and the EEPROMs in the control logic. I’ve been able to run a program to calculate the Fibonacci numbers from 2 up to 0xe9 (233).

Here is my estimate of the chips I need to build this. I could have this all wrong, so I’d love some feedback on if this is right, slightly off or in fact completely wrong:

|             Component                              |      Chip             |
|:---------------------------------------------------|:---------------------:|
| four 8-bit registers: IR, MAR, A, ALUout           | 74LS273               |
| one tri-state buffer                               | 74LS245               |
| one inverter                                       | 74LS04                |
| three 2-line to 1-line quad mux chips for PC logic | 74LS157               |
| three counters for the PC logic                    | 74LS163               |
| one counter for the phase                          | 74LS163               |
| one 2K x 8 ROM for instruction storage             | AT28C64B or AT28C16 ? |
| one 2K x 8 RAM                                     | M48Z02-150PC1         |
| two 1K x 8 ROMs for the control logic              | AT28C64B              |
| two 8K x 8 ROMs for the ALU                        | AT28C64B              |
 
That’s 19 chips for the CPU proper. For the clock and the SHO output, I probably also need:

+ 8-bit register for SHO (74LS273)
+ two hex to 7-segment decoders (MC14495)
+ two 7-seg LED displays
+ one 555 for clock signal
+ one OR gate to combine manual/555 clock tick
+ a pot for the 555 circuit, a toggle button and a pushbutton to control the clock signal
+ several breadboards
+ some tinned wire
+ several resistors for the 7-seg LED displays
+ several LEDs for showing individual lines
+ caps for the 555 circuit

That’s about another six chips, so a total of 25-ish chips for the CPU, clock and output. Does this sound reasonable?

![running Fibonacci](https://raw.githubusercontent.com/DoctorWkt/eeprom_cpu/master/Figs/fibonacci_run.gif)

Next tasks:
+ fully test the design in Logisim: ensure all instructions work as expected
+ get some real logic designers to review my design and see if it makes sense
+ fix up any mistakes pointed out by the real designers
+ design the clock circuitry, and design a physical layout in KiCad
+ buy the real components, wire it up, debug it and actually make it work in reality!
