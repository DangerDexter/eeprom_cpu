# Getting the CPU to Run Something

Right now this is in a state of on-going development. Here is what you can
do.

Install Logisim: on Ubuntu, do `sudo apt-get logisim`

Run `make` to build the ROM images needed: alu.rom, botctrl.rom, program.rom
and topctrl.rom

You can also run `./eas fib.s | less`

This will
+ assemble the program in `fib.s`
+ output the assembled code as `program.rom`
+ simulate the program. You should see the Fibonacci series being printed out in hexadecimal

Now that you know that the `fib.s` program should run correctly, run Logisim
and open up the file `ep16cpu.circ`. This is the CPU design that I've done so
far.

Right-click on the ALU and view the ALU. This should open up a display of the
ALU and the two ROMs. Right-click on the top ROM and choose Load Image.
Choose the file `alu.rom` and click on Open to load this ROM image.
Load the same ROM image file into the bottom ROM. You now have a working
8-bit ALU.

Over in the left-hand column, double-click on the Control word. This
should open up a display of the control logic, and you should again see two
ROMs. In the top ROM, load the file `topctrl.rom`. In the bottom ROM, load
the file `botctrl.rom`. You now have a working control logic.

Over in the left-hand column, double-click on the word 'main'. You should be
back at the top-level of the design. Right-click on the top ROM (the one
below it is actually RAM), and load the file `program.rom`. You are now
ready to run the `fib.s` program on the simulated hardware.

Click on the word Simulate in the menu bar at the top. Set a tick frequency,
e.g. 32Hz, and then toggle Ticks Enabled. The simulation will start, and
you should see the Fibonacci series appear in hexadecimal on the 7-segment
LED display on the right.
