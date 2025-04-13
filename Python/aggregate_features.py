def group_by_first_variable(input_file, output_file):
    with open(input_file, 'r') as file:
        lines = file.readlines()

    grouped_data = {}
    current_group = None

    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue  # Skip empty lines

        # Identify the first variable (group)
        if i % 6 == 0:  # First variable appears every 6th line
            current_group = line
            if current_group not in grouped_data:
                grouped_data[current_group] = []
        # Identify the second variable
        elif i % 6 == 1:  # Second variable appears right after the first variable
            if current_group:
                grouped_data[current_group].append(line)

    # Write the grouped output to a file
    with open(output_file, 'w') as file:
        for group, variables in grouped_data.items():
            file.write(f"{group}\n")
            file.write(f"\t{', '.join(variables)}\n\n")

# Example usage
input_file = "input.txt"  # Replace with the path to your input file
output_file = "output.txt"  # Replace with the desired output file path
group_by_first_variable(input_file, output_file)