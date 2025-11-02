import os

mapfiles_dir = './../mapfiles'

for filename in os.listdir(mapfiles_dir):
    if not filename.endswith('.map'):
        continue
    filepath = os.path.join(mapfiles_dir, filename)
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Track the minimum point index and corresponding data for each path
    path_info = {}
    for line in lines:
        stripped_line = line.strip()
        if not stripped_line:
            continue
        parts = stripped_line.split(';', 6)
        if len(parts) != 7:
            continue
        parts = [p.strip() for p in parts]
        path_index, point_index_str, data = parts[0], parts[1], parts[6]
        try:
            point_index = int(point_index_str)
        except ValueError:
            continue  # Skip lines with invalid pointIndex
        
        if path_index not in path_info:
            path_info[path_index] = (point_index, data)
        else:
            current_min, current_data = path_info[path_index]
            if point_index < current_min:
                path_info[path_index] = (point_index, data)
    
    # Determine excluded path_indices
    excluded = set()
    for path_index, (min_pidx, data) in path_info.items():
        if 'jet' in data or 'air' in data:
            excluded.add(path_index)
    
    # Filter lines, preserving original lines including whitespace and newlines
    filtered_lines = []
    for line in lines:
        stripped_line = line.strip()
        if not stripped_line:
            continue
        parts = stripped_line.split(';', 6)
        if len(parts) < 7:
            continue
        parts = [p.strip() for p in parts]
        path_index = parts[0]
        if path_index not in excluded:
            filtered_lines.append(line)
    
    # Write the filtered lines back to the file
    with open(filepath, 'w') as f:
        f.writelines(filtered_lines)