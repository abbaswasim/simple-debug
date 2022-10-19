#!/usr/bin/python
import os
import os.path
from os.path import exists

import lldb
import json

def load_simple_debug_json(debugger):
    file_name = ".simple-debug.json" 
    found_file_name = "" 
    working_dir = os.getcwd()

    while True:
        parent_dir = os.path.dirname(working_dir)
        current_file_name = os.path.join(working_dir, file_name)
        if exists(current_file_name):
            found_file_name = current_file_name
            break;
        else:
            if working_dir == parent_dir: #if dir is root dir
                break
            else:
                working_dir = parent_dir
                
    if found_file_name:
        print("simple-debug reading breakpoints from:" + found_file_name)
        with open(found_file_name, "r") as json_file:
            data = json.load(json_file)
            for simple_breakpoint in data:
                src_file_name = simple_breakpoint["file"]
                src_breakpoints = simple_breakpoint["breakpoints"]
                if src_breakpoints:
                    for breakpoint_locations in src_breakpoints:
                        if "function" in breakpoint_locations:
                            func_name = breakpoint_locations["function"]
                            debugger.HandleCommand('breakpoint set -n ' + func_name)
                        else:
                            line_num = breakpoint_locations["line"]
                            debugger.HandleCommand('breakpoint set -f ' + src_file_name + " -l " + str(line_num))
    else:
        print("Couldn't find .simple-debug.json file in the project or its parents.")

# And the initialization code to add your commands 
def __lldb_init_module(debugger, dict):
    load_simple_debug_json(debugger)
    print("simple-debug created the following breakpoints:")
    debugger.HandleCommand('breakpoint list')
