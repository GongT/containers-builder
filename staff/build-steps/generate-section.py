import json
import pprint
import sys, yaml


input_yaml = sys.argv[1]
name = sys.argv[2]
step = sys.argv[3]
title = sys.argv[4]

data = yaml.full_load(input_yaml)[0]

if 'name' not in data:
    data['name'] = title
else:
    data['name'] += ': ' + title
    
if 'env' not in data or data['env'] is None:
    data['env'] = dict()

for i in sys.argv[5:]:
    [k,v] = i.split('=', 1)
    data['env'][k] = v

data['env']['_BUILDSCRIPT_RUN_STEP_'] = f"{step}:{name}"

data['id'] = f"{name.replace('-','_')}_step_{step}"

yaml.dump([data], sys.stdout, allow_unicode=True)
