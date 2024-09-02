.text

init_student:

    li $t0, 0x3FF            # masking of 0x3FF
    and $t2, $a1, $t0        # $ loading the lower 10 bits
    li $t3, 1024             # Load 1024 
    mul $t3, $a0, $t3        # Multiply $a0 by 1024 to shift it left by 10 bits
    or $t2, $t3, $t2         # combine ID and credit
    sw $t2, 0($a3)           # Store the combined word at 1st word
    sw $a2, 4($a3)           # Store the name pointer immediately after the ID/credits word
    jr $ra  
    
print_student:
    move $t1, $a0          # Base address of record in $t1
    lw $t2, 0($a0)         # $t2 holds both the ID and credits

    srl $t3, $t2, 10       # Isolate the ID by shifting right
    li $v0, 1              
    move $a0, $t3          
    syscall                # Print the ID

    li $a0, ' '            
    li $v0, 11             
    syscall                # Print space

    li $t4, 1              # create mask for isolating credts
    sll $t4, $t4, 10       # Shift left by 10 bits, $t4 = 1024
    addi $t4, $t4, -1      # Subtract 1 to get 1023

    and $t3, $t2, $t4      # isolate the credits
    li $v0, 1              
    move $a0, $t3          
    syscall                # Print credits

    li $a0, ' '           
    li $v0, 11            
    syscall                # Print space

    lw $a0, 4($t1)         # Retrieve the pointer to the name from the second word of the record
    li $v0, 4              # Syscall code for printing a string
    syscall                # Print the name

    jr $ra                 # Return to the calling function


init_student_array:
    move $t1, $a0              # Preserve num_students 
    move $t7, $a1              # current ID
    move $t8, $a2              # current credits 
    move $t9, $a3              # current start
    lw $t4, 0($sp)             # current record 
    li $t6, 0                  # loop counter from 0
    addi $sp, $sp, -4          # Decrement stack pointer to make space
    sw $ra, 0($sp)             # Store $ra on the stack

forloop1:   # Loop to initialize student records[]

    beq $t6, $t1, loopexit  # exit condition

    lw $a0, 0($t7)             # ID into $a0
    lw $a1, 0($t8)             # credits into $a1
    move $a2, $t9              # $a2 points to current name
    move $a3, $t4              # $a3 points to current record
    jal init_student          
    addi $t7, $t7, 4           # increment id[] pointer
    addi $t8, $t8, 4           # increment credit[] pointer
    addi $t4, $t4, 8           # increment record[] pointer 

    forloop2:                  # Loop to go to next char pointer of the name
        lb $t5, 0($t9)         # current position
        addi $t9, $t9, 1       # Increment pointer to next char
        bnez $t5, forloop2     # If not zero, continue loop

    addi $t6, $t6, 1          # Increment student index
    j forloop1                # Jump back to start of the main loop

loopexit:
   
    lw $ra, 0($sp)            # Load the original $ra
    addi $sp, $sp, 4          # Restore the stack pointer
    jr $ra                    

insert:

    lw $t0, 0($a0)               # get the id and credits
    li $t5, 0xFFFFFC00           # Mask to isolate 22 MSB
    and $t0, $t0, $t5            # clear 10 LSB 
    srl $t0, $t0, 10             # align ID to right
    div $t0, $a2                 # Divide id by table_size
    mflo $t3                     # Get the quotient from the LO register
    mul $t3, $t3, $a2            # quotient * denominator
    sub $t3, $t0, $t3            # remainder
    move $t4, $t3                # initial index for loop detection

firstloop:
    li $t5, 4                  
    mul $t1, $t3, $t5            # get byte offset
    add $t1, $t1, $a1            # get the actual address
    lw $t2, 0($t1)               # get the value at table[index]
    beq $t2, $zero, freespace    # NULL, branch to freespace
    li $t5, -1                  
    beq $t2, $t5, freespace      # tombstone, branch to freespace
    addi $t3, $t3, 1             # Increment index
    blt $t3, $a2, firstloop      # index < table size, continue loop
    move $t3, $zero              
    bne $t3, $t4, firstloop      # keep finding the next free space
    li $v0, -1                   # No free space founud
    jr $ra                      

freespace:
    sw $a0, 0($t1)               # Store the address
    move $v0, $t3                # get the index
    jr $ra      

search:
    move $t1, $a0             # ID
    div $t1, $a2              # Divide ID by table size
    mflo $t4                  # Get the quotient
    mul $t4, $t4, $a2         # Multiply quotient by table size
    sub $t1, $t1, $t4         # get the remainder

loop1:
    sll $t2, $t1, 2           # get byte offset from index
    add $t2, $t2, $a1         # get the address in the table

loop2:
    lw $t3, 0($t2)                  # Load first word
    beqz $t3, notthere              # Check for NULL
    li $t4, -1
    beq $t3, $t4, loop3             # Check for tombstone

    lw $t5, 0($t3)            # get the ID and credits
    getID:
        li $t6, 0xFFFFFC00    # Mask for ID 
        and $t5, $t5, $t6     # Apply mask
        srl $t5, $t5, 10      # Right align ID

    check_id_match:
        beq $t5, $a0, found1  # Compare ID

loop3:
    addi $t1, $t1, 1          # Increment index
    blt $t1, $a2, loop1       # start the loop again
    li $t1, 0                 # Reset index to wrap around
    bne $t1, $t4, loop1       # Continue looping

notthere:
    li $v0, 0                 # Set not found return value
    li $v1, -1                # Set not found index
    jr $ra                    # Return

found1:
    move $v0, $t3             # Set found record's address to return
    move $v1, $t1             # Set found index to return
    jr $ra                    # Return


delete:

    addiu $sp, $sp, -12      # Make space for three registers
    sw $ra, 0($sp)           # Save return address
    sw $t0, 4($sp)           # Save $t0
    sw $t7, 8($sp)           # Save $t7
    move $t0, $a1            # Hash table pointer
    move $t7, $a2            # Table size
    jal search               # Call search
    move $t8, $v1            # Index from search
    li $t9, -1               # Comparison value for not found
    beq $t8, $t9, exit1    # Skip if not found
    sll $t9, $t8, 2          # Index to offset
    add $t9, $t9, $t0        # Calculate address
    li $t0, -1               # Tombstone marker
    sw $t0, 0($t9)           # Set tombstone
    
exit1:
    lw $ra, 0($sp)           # Restore $ra
    lw $t0, 4($sp)           # Restore $t0
    lw $t7, 8($sp)           # Restore $t7
    addiu $sp, $sp, 12       # Reclaim stack space
    move $v0, $t8            # Result index
    jr $ra                   # Return
