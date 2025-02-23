.MODEL TINY


.DATA
    PORTA1 equ 0000h
    PORTB1 equ 0002h
    PORTC1 equ 0004h
    CWREG1 equ 0006h
    
    PORTA2 equ 0001h
    PORTB2 equ 0003h
    PORTC2 equ 0005h
    CWREG2 equ 0007h

    
.CODE
.STARTUP
       
    init:   
      ORG  0000h
      
      ; This register will serve as internal memory and store the number of people in the room.
      MOV  dl, 00h
            
      ; Set up the first PPI to read from Port A and write to Port B and Port C.
      MOV  al, 10010000b
      OUT  CWREG1, al
      
      ; Set up the second PPI to write to Port C [each output line is a row of 3 lights].
      MOV  al, 10010010b
      OUT  CWREG2, al

 
    ; "main" serves as our event loop and the functions check_entry and check_exit will handle the rest.        
    main:   
      CALL check_entry
      CALL check_exit
      JMP  main 
  
    
    delay PROC NEAR
    ; A small timed delay. The caller should set CX before calling.
      delay1:  
        NOP
        DEC  cx
        JNE  delay1
        RET
    delay ENDP

    update_display PROC NEAR
    ; Update the 2 7SEGs to display the number of people in the room.
        MOV  bl, 10d
        MOV  ax, dx
        DIV  bl ; al: quotient, ah: remainder
        MOV  bl, ah
        SHL  ax, 4
        ADD  al, bl
        OUT  PORTC1, al
        RET
    update_display ENDP
    
    incr_cnt PROC NEAR
    ; Increase the count value and update the display.
        INC  dl;
        CALL update_display;
        CALL light_rows
        RET
    incr_cnt ENDP
               
               
    decr_cnt PROC NEAR
    ; Decrease the count value and update the display.
        DEC  dl;
        CALL update_display;
        CALL light_rows
        RET
    decr_cnt ENDP
  
    
    open_door PROC NEAR
    ; Open the door by turning the stepper motor to 180deg. 
        MOV  al, 00000001b
        OUT  PORTB1, al
        RET
    open_door ENDP
    
    
    close_door PROC NEAR
    ; Close the door by turning the stepper motor to 0deg.
        MOV  al, 00000010b
        OUT  PORTB1, al
        RET
    close_door ENDP 
                 
                 
    check_entry PROC NEAR
        ; Check to see if the external pressure sensor has been triggered.
        IN   al, PORTA1
        CMP  al, 00000001b
        JNE  check_entry4
                
        ; Open the door once the external pressure sensor has been triggered.
        CALL open_door
        MOV  cx, 0FFFFh
        CALL delay
            
        ; Check to see if the internal pressure sensor has been triggered. Provide a small window of time for entry.
        MOV  cx, 0FFFFh
      check_entry1:
        IN   al, PORTA1
        CMP  al, 00000010b
        JE   check_entry2 
        DEC  cx
        JNZ  check_entry1
        JMP  check_entry3
            
      check_entry2:
        ; If the person entered then the count should be incremented.
        CALL incr_cnt
        
      check_entry3:
        ; Close the door.     
        CALL close_door
      check_entry4:
        RET     
    check_entry ENDP
                    
         
    check_exit PROC NEAR
        ; Check to see if the external pressure sensor has been triggered.
        IN   al, PORTA1
        CMP  al, 00000010b
        JNE  check_exit4
                
        ; Open the door once the external pressure sensor has been triggered.
        CALL open_door
        MOV  cx, 0FFFFh
        CALL delay
            
        ; Check to see if the internal pressure sensor has been triggered. Provide a small window of time for entry.
        MOV  cx, 0FFFFh
      check_exit1:
        IN   al, PORTA1
        CMP  al, 00000001b
        JE   check_exit2 
        DEC  cx
        JNZ  check_exit1
        JMP  check_exit3
            
      check_exit2:
        ; If the person exited then the count should be decremented.
        CALL decr_cnt
        
      check_exit3:
        ; Close the door.     
        CALL close_door
      check_exit4:
        RET     
    check_exit ENDP
                   
                   
    light_rows PROC NEAR
        ; Check to see how many people are in the room (using the value in dl),
        ; then accordingly determine the number of rows that need to be lit up.
        ; start filling from ROW1 onwards.
        ; Our assumption is that the rows seat 5 people each.
        ; Thus the total capacity of the conference room is 5*6 = 30 people.
        MOV  al, 00d
        
        CMP  dl, 25d
        JLE  light_rows1
        INC  al
      light_rows1:
        SHL  al, 1 ; Moving this up by one line would slightly improve speed (heuristic).
        
        CMP  dl, 20d
        JLE  light_rows2
        INC  al
      light_rows2:
        SHL  al, 1
        
        CMP  dl, 15d
        JLE  light_rows3
        INC  al
      light_rows3:
        SHL  al, 1
        
        CMP  dl, 10d
        JLE  light_rows4
        INC  al
      light_rows4:
        SHL  al, 1
        
        CMP  dl, 05d
        JLE  light_rows5
        INC  al
      light_rows5:
        SHL  al, 1
        
        CMP  dl, 00d
        JE  light_rows6
        INC  al
        
      light_rows6:
        OUT  PORTC2, al
        
        RET   
    light_rows ENDP    

END


; POSSIBLE OPTIMIZTIONS:
; 1. Use a flag/moniter/semaphore to prevent entry/exit race conditions.
