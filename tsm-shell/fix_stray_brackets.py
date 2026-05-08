#!/usr/bin/env python3
# Removes stray standalone }); lines that appear back-to-back
# These are leftover from incomplete route removal

SERVER = '/workspaces/tsm-shell/server.js'

f = open(SERVER, 'r')
lines = f.readlines()
f.close()

out = []
i = 0
removed = 0
while i < len(lines):
    line = lines[i]
    # Check if this line is }); and the previous non-empty line was also });
    if line.strip() == '});' and out:
        # Look back at last non-empty line
        prev = ''
        for p in reversed(out):
            if p.strip():
                prev = p.strip()
                break
        if prev == '});':
            print(f'Removing stray }}); at line {i+1}')
            removed += 1
            i += 1
            continue
    out.append(line)
    i += 1

open(SERVER, 'w').writelines(out)
print(f'Removed {removed} stray lines')
