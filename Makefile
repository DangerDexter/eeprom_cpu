all: alu.rom program.rom topctrl.rom

clean:
	rm -f alu.rom botctrl.rom program.rom topctrl.rom

alu.rom:
	./gen_romalu

topctrl.rom:
	./gen_controlrom

program.rom:
	./eas fib.s
