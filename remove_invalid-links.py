import os
import json

mapfiles_dir = 'mapfiles'

for filename in os.listdir(mapfiles_dir):
    if not filename.endswith('.map'):
        continue
    # Step 1: Collect all existing path indices from all .map files
    path_indices = set()

    filepath = os.path.join(mapfiles_dir, filename)
    with open(filepath, 'r') as f:
        for line in f:
            stripped_line = line.strip()
            if not stripped_line:
                continue
            parts = stripped_line.split(';', 6)
            if len(parts) < 7:
                continue
            path_index = parts[0].strip()
            path_indices.add(path_index)

#    Step 2: Process each file to remove invalid LinkMode and Links entries
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    modified = False
    
    for line in lines:
        original_line = line
        stripped_line = line.strip()
        if not stripped_line:
            new_lines.append(line)
            continue
        
        # Split into parts up to the data field
        semicolon_indices = [i for i, c in enumerate(line) if c == ';']
        if len(semicolon_indices) < 6:
            new_lines.append(line)
            continue
        
        sixth_semi = semicolon_indices[5]
        prefix = line[:sixth_semi + 1]
        data_part = line[sixth_semi + 1:]
        
        # Split data part into leading whitespace, content, and trailing whitespace
        stripped_data = data_part.strip()
        if not stripped_data:
            new_lines.append(line)
            continue
        
        leading_ws = data_part[:data_part.find(stripped_data)]
        trailing_ws = data_part[data_part.find(stripped_data) + len(stripped_data):]
        
        # Process the data content
        modified_data = stripped_data
        
        # Attempt to parse as JSON object
        try:
            data_dict = json.loads(modified_data)
        except json.JSONDecodeError:
            # Invalid JSON format, skip processing
            pass
        else:
            # Check for LinkMode and Links keys
            if 'LinkMode' in data_dict and 'Links' in data_dict:
                links = data_dict['Links']
                invalid_found = False
                
                # Check each link's path index
                for link in links:
                    if (
                        not isinstance(link, list) 
                        or len(link) < 1 
                        or str(link[0]) not in path_indices
                    ):
                        invalid_found = True
                        break
                
                # Remove LinkMode and Links if any invalid links found
                if invalid_found:
                    del data_dict['LinkMode']
                    del data_dict['Links']
                    # Convert back to string and unwrap
                    new_data = json.dumps(data_dict, separators=(',', ':')).strip('{}')
                    modified_data = new_data
        
        # Rebuild the line with original whitespace
        new_data_part = f"{leading_ws}{modified_data}{trailing_ws}"
        new_line = f"{prefix}{new_data_part}"
        
        if new_line != original_line:
            modified = True
        new_lines.append(new_line)
    
    # Write back if modifications were made
    if modified:
        with open(filepath, 'w') as f:
            f.writelines(new_lines)