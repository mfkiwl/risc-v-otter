#------------------------------------------
# Counts the number of interrupts received
# via debounced button presses and displays
# the number on the 7-segment display using
# a lookup table. After reaching 49 counts,
# the display resets to zero and continues.
#------------------------------------------

# BCD to decimal conversions for the 7-segment display
.data
seg:        .space 11   # Save space for 10-byte lookup table 
an:         .space 4    # 4-byte LUT for anodes

.text
#------------------------------------------------------------
# Subroutine: main
#
# Handles the background task of multiplexing the display.
#------------------------------------------------------------
main:
init:       call        load_lut                # Load values into LUT
            li          x15, 0x1100C004         # segments port addr
            li          x16, 0x1100C008         # anodes port addr
            li          sp, 0x0000A000          # init stack pointer
            la          x6, btn_intr            # Load ISR addr 
            csrrw       x0, mtvec, x6           # Put ISR addr in mtvec
            la          x29, an                 # LUT anodes base address
            la          x30, seg                # LUT segments base address
            li          x25, 0                  # 10s digit
            li          x26, 0                  # 1s digit
            li          x27, 3                  # Current anode (3 -> 0: L -> R)
            li          x28, 0xF                # All anodes off
            li          x20, 1                  # 10s digit anode
            csrrw       x0, mie, x20            # Enable interrupts

loop:       sw          x28, 0(x16)             # Turn off all anodes
            call        choose_seg              # Choose correct value to display
update:     call        update_seg              # Update the current segment
            call        update_an               # Enable the current anode
            call        delay_ff                # Delay
            j           loop                    # Do it again
            
#------------------------------------------------------------
# ISR: btn_intr
#
# Increments the total interrupt count when an interrupt is
# received. Rolls over to zero after 49 interrupts.
#------------------------------------------------------------
btn_intr:
            addi         x26, x26, 1            # Add 1 to 1s digit
            li           x20, 10                # Max 1s digit value
            bltu         x26, x20, intr_done    # If 1s digit goes to 10
            mv           x26, x0                # Clear 1s digit
            addi         x25, x25, 1            # Increment 10s digit
            li           x20, 5                 # Max 10s digit value
            bltu         x25, x20, intr_done    # If 10s digit goes to 5
            mv           x25, x0                # Clear 10s digit
intr_done:  li           x20, 1                 # Restore x20
            csrrw        x0, mie, x20           # Enable interrupts
            mret                                # Done


#------------------------------------------------------------
# Subroutine: update_an
#
# Updates the current anode using the LUT according to the
# value passed in x27.
#------------------------------------------------------------
update_an:
            addi        sp, sp, -4              # adjust sp
            sw          x20, 0(sp)              # Push x20
            add         x29, x29, x27           # Get correct LUT addr
            lbu         x20, 0(x29)             # Get value from LUT
            sw          x20, 0(x16)             # Store value to anodes addr
            sub         x29, x29, x27           # Restore LUT addr
            addi        x27, x27, -1            # Go to next anode
            bgez        x27, next_an            # If not at last anode, continue to next
            li          x27, 3                  # Start at anode 3 again
next_an:    lw          x20, 0(sp)              # Pop x20
            addi        sp, sp, 4               # Restore sp
            ret                                 # Done

#------------------------------------------------------------
# Subroutine: update_seg
# 
# Updates the 7-segment output (address in x15)
# to the value passed in x10
#------------------------------------------------------------
update_seg:
            addi        sp, sp, -4              # Adjust sp
            sw          x20, 0(sp)              # Push x20
            add         x30, x30, x10           # Get correct LUT addr
            lbu         x20, 0(x30)             # Get value from LUT
            sw          x20, 0(x15)             # Store value to segments addr
            sub         x30, x30, x10           # Restore LUT addr
            lw          x20, 0(sp)              # Pop x20
            addi        sp, sp, 4               # Adjust sp
            ret                                 # Done
            
#------------------------------------------------------------
# Subroutine: choose_seg
#
# Fills register x10 with the correct value to be displayed
# based on the current anode. Leftmost anodes are blank,
# while rightmost are the 10s digit and 1s digit.
#------------------------------------------------------------
choose_seg:
            beq         x27, x20, do_10s        # If currently on 10s digit
            beq         x27, x0, do_1s          # If currently on 1s digit
            li          x10, 0xA                # All segments off otherwise
            j           c_done                  # Update segment
do_10s:     beqz        x25, c_done             # lead-zero blanking on 10s digit (if 0)
            mv          x10, x25                # Update segments to value in 10s digit
            j           c_done                  # Update segment
do_1s:      mv          x10, x26                # Update segments to value in 1s digit
c_done:     ret                                 # Done

#------------------------------------------------------------
# Subroutine: delay_ff
#
# Delays for a count of FF. Unknown how long that is but it
# is plenty of time for display multiplexing
#
# tweaked registers: x31
#------------------------------------------------------------
delay_ff:
            li          x31,0xFF                # load count
d_loop:     beq         x31,x0,d_done           # leave if done
            addi        x31,x31,-1              # decrement count
            j           d_loop                  # rinse, repeat
d_done:     ret                                 # leave it all behind
#--------------------------------------------------------------

#--------------------------------------------------------------
# Subroutine: load_lut
# 
# Loads the LUT with values for seg and an
#--------------------------------------------------------------
load_lut:
            la          x10, seg
            li          x11, 0x03
            sb          x11, 0(x10)
            li          x11, 0x9F
            sb          x11,1(x10)
            li          x11,0x25
            sb          x11,2(x10)
            li          x11,0x0D
            sb          x11,3(x10)
            li          x11,0x99
            sb          x11,4(x10)
            li          x11,0x49
            sb          x11,5(x10)
            li          x11,0x41
            sb          x11,6(x10)
            li          x11,0x1F
            sb          x11,7(x10)
            li          x11,0x01
            sb          x11,8(x10)
            li          x11,0x09
            sb          x11,9(x10) 
            li          x11,0xFF
            sb	        x11,10(x10)         # Value 10 will be blank

            la          x10, an
            li          x11, 0x07
            sb          x11, 0(x10)
            li          x11, 0x0B
            sb          x11, 1(x10)
            li          x11, 0x0D
            sb          x11, 2(x10)
            li          x11, 0x0E
            sb          x11, 3(x10)
            ret
