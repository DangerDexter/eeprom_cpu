all: botctrl.rom botalu.rom

botctrl.rom: gen_controlrom control_logic
	./gen_controlrom control_logic

botalu.rom: gen_romalu
	./gen_romalu

clean:
	rm -f *.rom
