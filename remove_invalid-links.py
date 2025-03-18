import os
import json

mapfiles_dir = 'mapfiles'

for filename in os.listdir(mapfiles_dir):
    if not filename.endswith('.map'):
        continue
    # Step 1: Collect all existing path indices from all .map files
    path_indices = set()
    all_links = []

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
            
            if "Links" in parts[6]:
                all_links.append(parts)

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
                invalid_links = []
                
                # Check each link's path index
                for link in links:
                    if (
                        not isinstance(link, list) 
                        or len(link) < 1 
                        or str(link[0]) not in path_indices
                    ):
                        invalid_links.append(link)
                        break
                    
                    invalid_found = True
                    for comp_link in all_links:
                        if int(link[0]) == int(comp_link[0]):
                            if int(link[1]) == int(comp_link[1]):
                                # now compare the link itself of the connecting path
                                link_data = comp_link[6].split("\"Links\":[[")[1].split("]]")[0].split("],[")
                                for data in link_data:
                                    parts = data.split(",")
                                    # must match pathindex and pointindex of the link
                                    path_index = line.split(";")[0]
                                    point_index = line.split(";")[1]
                                    if int(parts[0]) ==  int(path_index) and  int(parts[1]) == int(point_index):
                                        # if it matches, then it is a valid link
                                        invalid_found = False
                                        break
                    if invalid_found:
                        invalid_links.append(link)
                        break

                
                # Remove LinkMode and Links if any invalid links found
                if len(invalid_links) > 0:
                    if len(links) == len(invalid_links):
                        # Remove entire data content if all links are invalid
                        del data_dict['LinkMode']
                        del data_dict['Links']
                        # Convert back to string and unwrap
                        new_data = json.dumps(data_dict, separators=(',', ':')).strip('{}')
                        modified_data = ""
                        if new_data:
                            modified_data = '{' + new_data + '}'
                    else:
                        # Remove only invalid links
                        data_dict['Links'] = [link for link in links if link not in invalid_links]
                        # Convert back to string and unwrap
                        new_data = json.dumps(data_dict, separators=(',', ':')).strip('{}')
                        modified_data = ""
                        if new_data:
                            modified_data = '{' + new_data + '}'
        
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
            
        # break # remove this line to process all files