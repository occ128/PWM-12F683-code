PIC12F683 Assembly Program

Overview
This repository contains assembly language files for a program designed to run on the PIC12F683 microcontroller. 
The program is structured to control and manage various hardware components, with a focus on temperature management, LED control, and user input processing.

Files Description

Main.ASM:
The main assembly program file. It includes the primary logic and flow of the program.

DC.asm: Handles the calculation of duty cycles.
LED.asm: Manages the LED operations.
Lib.asm: A library of subroutines used across the program.
Macro.ASM: Contains macro definitions for simplifying complex instruction sets.
P12F683.INC: Standard header file with configurations and register definitions for the PIC12F683.
Vars.asm: Defines variables and constants used in the program.
Setup and Configuration
To use these assembly files, you will need an assembler compatible with PIC microcontrollers, such as MPLAB X IDE from Microchip. Load the files into the assembler, and ensure that the PIC12F683 microcontroller is selected as the target device.

Clock Configuration
The program is configured to run with the internal oscillator of the PIC12F683 set to a 4 MHz clock rate. This setting is crucial for the correct timing and operation of the program.

Usage
Compile the .asm files using your assembler.
Upload the compiled program to a PIC12F683 microcontroller.
The program can be interfaced with the appropriate hardware as per the functionality defined in the assembly files.
Contributing
We welcome contributions to this project! Please feel free to submit pull requests or open issues for bugs and feature suggestions.

License
[Add License Information Here]

Contact
[Your Name] - [Your Email]
Project Link: [GitHub Repository URL]

Replace placeholders like [Your Name], [Your Email], and [GitHub Repository URL] with your actual contact information and project link. Also, feel free to expand or modify sections as needed based on the specifics of your project and any additional documentation you want to include.
