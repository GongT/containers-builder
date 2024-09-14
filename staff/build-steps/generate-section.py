import pprint
import sys, yaml


input_yaml = sys.argv[1]
title = sys.argv[2]
name = sys.argv[3]
step = sys.argv[4]

data = yaml.full_load(input_yaml)[0]

if 'name' not in data:
    data['name'] = title
else:
    data['name'] += ': ' + title
    
if 'env' not in data:
    data['env'] = dict()

data['env']['_BUILDSCRIPT_RUN_STEP_'] = f"{name}:{step}"
data['id'] = f"step_{step}"

yaml.dump([data], sys.stdout, allow_unicode=True)
