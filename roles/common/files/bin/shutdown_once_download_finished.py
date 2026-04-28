#!/usr/bin/env python3

import os
import time
import sys
from datetime import datetime

def file_last_changed(filename, last_modified=0.0):
    """
    Checks if a file has changed.

    Args:
        filename: Path to the file to monitor.
        last_modified: Last modification time in Unix seconds (float)

    Returns:
        (True, new_mtime) if the file has been updated, 
        (False, last_modified) otherwise.
    """
    try:
        new_mtime = os.path.getmtime(filename)
    except FileNotFoundError:
        new_mtime = 0

    if new_mtime != last_modified:
        # file has been updated
        return (True, new_mtime)

    return (False, last_modified)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <filename>")
        exit(1)

    filename = sys.argv[1]
    timeout = 600

    last_change_time = 0.0
    if not os.path.isfile(filename):
        print(f"ERROR: {filename} does not exist or is not a file. Exiting.")
        exit(1)

    while True:
        (res, last_change_time) = file_last_changed(filename, last_change_time)
        relative_time = time.time() - last_change_time
        if res:
            print(f"File {filename} changed {relative_time:.1f} seconds ago.")
        else:
            print(f"No change detected in file {filename} since {relative_time:.1f} seconds.")

        do_action = False
        if (relative_time) > timeout:
            # Replace 'your_command' with the actual command to execute
            print(f"No change detected in file {filename} since {relative_time:.1f}. Executing command ... ")
            do_action = True
        if not os.path.exists(filename):
            print(f"file {filename} does not exist. Executing command ... ")
            do_action = True
        if do_action:
            os.system('/bin/echo Hi. Would execute /usr/sbin/shutdown -h +10')

        time.sleep(10)  # Check for change every N seconds

