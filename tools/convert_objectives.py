import json
import os
from collections import defaultdict

safe_words = [
    "explore", "vehicle", "beacon", "spawn", "explore"
]


def sort_dict_and_string_lists(data):
    if isinstance(data, dict):
        return {k: sort_dict_and_string_lists(data[k]) for k in sorted(data)}
    elif isinstance(data, list):
        if all(isinstance(item, str) for item in data):
            return sorted(data)
        elif all(isinstance(item, (int, float)) for item in data):
            return data
        else:
            return [sort_dict_and_string_lists(item) for item in data]
    else:
        return data


def main():
    mapfiles_dir = './../mapfiles'

    for filename in os.listdir(mapfiles_dir):
        if not filename.endswith('.map'):
            continue
        input_file = os.path.join(mapfiles_dir, filename)
    
    
        # input_file = 'mapfiles/MP_012_ConquestSmall0.map'
        nodes_list = []
        paths_dict = defaultdict(list)
        
        with open(input_file, 'r') as f:
            for line in f:
                parts = line.strip().split(';', 6)
                if len(parts) < 7:
                    parts += [''] * (7 - len(parts))
                node = {
                    'pathIndex': parts[0],
                    'pointIndex': parts[1],
                    'transX': parts[2],
                    'transY': parts[3],
                    'transZ': parts[4],
                    'inputVar': parts[5],
                    'data': parts[6]
                }
                nodes_list.append(node)
                paths_dict[parts[0]].append(node)
        
        first_nodes = {}
        for path_index, nodes in paths_dict.items():
            for node in nodes:
                if node['pointIndex'] == "1":
                    first_nodes[path_index] = node
                    # print(node['pathIndex'])
                    break
        
        for path_index, node in first_nodes.items():
            data_str = node['data']
            if not data_str:
                continue
            try:
                data_json = json.loads(data_str)
            except json.JSONDecodeError:
                continue
            if isinstance(data_json, dict):
                if "Objectives" in data_json:
                    objectives = data_json["Objectives"]
                    if isinstance(objectives, list) and len(objectives) > 2 and "Vehicles" not in data_json:
                        del data_json["Objectives"]
                        if data_json == {}:
                            node['data'] = ""
                        else:
                            node['data'] = json.dumps(data_json,  separators=(',', ':'))
        
        single_objective_paths = []
        for path_index, node in first_nodes.items():
            data_str = node['data']
            if not data_str:
                continue
            try:
                data_json = json.loads(data_str)
            except json.JSONDecodeError:
                continue
            if isinstance(data_json, dict):
                if "Objectives" in data_json: #and "Vehicles" not in data_json:
                    objectives = data_json["Objectives"]
                    if isinstance(objectives, list) and len(objectives) == 1:
                        #if not "explore" in objectives[0] and not "vehicle" in objectives[0] and not "beacon" in objectives[0] and not "spawn" in objectives[0]:
                        single_objective_paths.append((path_index, objectives[0]))
                        # print(f"Single objective path: {path_index} with objective: {objectives[0]}")
                
        for path_index, objective in single_objective_paths:
            if path_index not in paths_dict:
                continue
            skip_path = False
            for word in safe_words:
                if word in objective:
                    # print(f"Skipping path {path_index} with objective {objective} due to safe word")
                    skip_path = True
                    break
            if skip_path:
                continue
            nodes_in_path = paths_dict[path_index]
            for node in nodes_in_path:
                data_str = node['data']
                if not data_str:
                    continue
                try:
                    data_json = json.loads(data_str)
                except json.JSONDecodeError:
                    continue
                if not isinstance(data_json, dict):
                    continue
                if "Links" in data_json:
                    links = data_json["Links"]
                    if not isinstance(links, list):
                        continue
                    for link in links:
                        if not isinstance(link, list) or len(link) < 1:
                            continue
                        linked_path_index = str(link[0])
                        if linked_path_index not in first_nodes:
                            continue
                        # print(f"Linking {path_index} to {linked_path_index} with objective {objective}")
                        skip_link = False
                        for single_objective_path in single_objective_paths:
                            if int(single_objective_path[0]) == int(linked_path_index): #or "vehicle" in single_objective_path[1] or "beacon" in single_objective_path[1]  or "explore" in single_objective_path[1] or "spawn" in single_objective_path[1]
                                # print(f"Skipping link to single objective path: {linked_path_index}")
                                skip_link = True
                                break
                        if skip_link:
                            continue
                        linked_first_node = first_nodes[linked_path_index]
                        linked_data_str = linked_first_node['data']
                        linked_data_json = {}
                        if linked_data_str:
                            try:
                                linked_data_json = json.loads(linked_data_str)
                            except json.JSONDecodeError:
                                linked_data_json = {}
                        if not isinstance(linked_data_json, dict):
                            linked_data_json = {}
                        if "Objectives" not in linked_data_json:
                            linked_data_json["Objectives"] = []
                        objectives_list = linked_data_json["Objectives"]
                        if not isinstance(objectives_list, list):
                            objectives_list = []
                            linked_data_json["Objectives"] = objectives_list
                        if objective not in objectives_list:
                            objectives_list.append(objective)
                        linked_data_json = sort_dict_and_string_lists(linked_data_json)
                        if linked_data_json == {}:
                            linked_first_node['data'] = ""
                        else:
                            linked_first_node['data'] = json.dumps(linked_data_json, separators=(',', ':'))
        # TODO:                
        # now check, if a new objective was added to a first-node, that now only has one objective, if so, remove the objective
        for path_index, node in first_nodes.items():
            data_str = node['data']
            if not data_str:
                continue
            try:
                data_json = json.loads(data_str)
            except json.JSONDecodeError:
                continue
            if isinstance(data_json, dict):
                if "Objectives" in data_json:
                    objectives = data_json["Objectives"]
                    if isinstance(objectives, list) and len(objectives) == 1:
                        # if the objective is now a single objective, remove it
                        
                        remove_objective = True
                        for single_objective_path in single_objective_paths:
                            if int(single_objective_path[0]) == int(path_index): 
                                remove_objective = False
                                break
                        if remove_objective:
                            del data_json["Objectives"]
                            if data_json == {}:
                                node['data'] = ""
                            else:
                                node['data'] = json.dumps(data_json, separators=(',', ':'))
                            # print("removed single objective from path:", path_index)
        
        with open(input_file, 'w') as f:
            for node in nodes_list:
                line = f"{node['pathIndex']};{node['pointIndex']};{node['transX']};{node['transY']};{node['transZ']};{node['inputVar']};{node['data']}\n"
                f.write(line)

if __name__ == "__main__":
    main()