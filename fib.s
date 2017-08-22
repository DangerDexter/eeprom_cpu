start:	lca	1
	sma	num1
	sma	num2		# Set num1 and num2 to 1
loop:	lma	num1
	lmb	num2
	adda			# A= num1+num2
	jcs	end		# Exit when carry
	sma	num3		# Save the new Fib number

				# Time to print it out in decimal
	lcb	200
	subb			# B= A - 200
	jvc	below200	# Jump if it is below 200
	lca	'2'
	ttoa			# Print the '2' digit'
	tba			# and copy the remainder back into A
	jmp	tensdigit	# Go to deal with the tens digits
below200: lcb	100		# Ok, is it above or below 100?
	subb			# B= A - 100
	jlt	below100	# Jump if it is below 100
	lca	'1'
	ttoa			# Print the '1' digit'
	tba			# and copy the remainder back into A
	jmp	tensdigit	# Go to deal with the tens digits
below100: lcb	32	
	ttob			# It was below 100, so print out a space
tensdigit: lcb '0'		# Set up digit to be the ASCII '0' value
	smb	digit
tenloop: lcb	10
	suba			# Subtract 10 from the number
	jlt	endten		# Exit the loop once we get a negative result
	incm	digit		# Add one to the digit to print out
	jmp	tenloop
endten: lmb	digit		# We've subtracted enough 10s
	ttob			# Print out the ASCII digit of the count of 10s
	lcb	58		# Add '0'+10 back to A so we have the
	adda			# final digit in ASCII format
	ttoa			# and print it out
	lcb	10		# Print out a newline
	ttob
				# Back to Fibonacci
	lmb	num2
	smb	num1		# Shuffle num2 into num1
	lmb	num3
	smb	num2		# Shuffle num3 into num2
	jmp 	loop
end:	jmp	end

num1:	byte
num2:	byte
num3:	byte
digit:	byte
