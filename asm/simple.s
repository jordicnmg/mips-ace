	.text
main:
	la $t0, value
	li $s0, 0x0A
loop:
	lw $t1, 0($t0)
	addi $t2, $t1, 48
	move $a0, $t2
	li $v0, %PRINT_CHAR
	syscall
	beq $t1, $zero, exit
	addi $t0, $t0, 4
	j loop
exit:
	move $a0, $s0
	li $v0, %PRINT_CHAR
	syscall
	li $v0, %EXIT
	syscall

	.data
value: .word 3, 2, 1, 0
