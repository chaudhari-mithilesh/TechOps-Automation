# TechOps Script README

## Requirements

This script requires the following libraries to be installed:

- sshpass
- xmllint
- dos2unix

## How to Execute

1. Clone this repository to your local machine.

2. Ensure all prerequisite libraries are installed on your system.

3. Edit the `credentials.xml` file with your actual SSH details.

4. Run the following commands:
	`dos2unix credentials.xml`
	`dos2unix TechOps.sh`
	`chmod +x TechOps.sh`
	`./TechOps.sh`



5. Choose an action from the available options presented in the script.

## Reporting Bugs

If you encounter any bugs or issues, please report them to techops@wisdmlabs.com

## Usage Notes

- Make sure to replace the placeholder values in `credentials.xml` with your actual SSH credentials.
- The script uses `dos2unix` to ensure proper line endings for Unix-like systems.
- After running the script, follow the prompts to choose your desired action.

Remember to handle sensitive information securely, especially when dealing with SSH credentials.

