import json
import pprint
import sys, yaml


input_yaml = sys.argv[1]
step = sys.argv[2]
title = sys.argv[3]

data = yaml.full_load(input_yaml)[0]

if 'name' not in data:
    data['name'] = title
else:
    data['name'] += ': ' + title
    
if 'run' not in data:
    data['run'] = 'build_step'
    
if 'env' not in data or data['env'] is None:
    data['env'] = dict()

for i in sys.argv[4:]:
    [k,v] = i.split('=', 1)
    data['env'][k] = v

data['id'] = f"step_{step}"

yaml.dump([data], sys.stdout, allow_unicode=True)
