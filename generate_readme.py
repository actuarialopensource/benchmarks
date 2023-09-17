import yaml

def read_yaml_file(filename):
    with open(filename, 'r') as stream:
        try:
            return yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

def generate_readme():
    julia_yaml = read_yaml_file('Julia/benchmark_results.yaml')
    python_yaml = read_yaml_file('Python/benchmark_results.yaml')
    r_yaml = read_yaml_file('R/benchmark_results.yaml')
    final_result = {}
    for d in (julia_yaml, python_yaml, r_yaml):
        for k, v in d.items():
            if k not in final_result:
                final_result[k] = []
            final_result[k].append(v)

    # read the text in readme_template.md and store it as a string "template"
    with open('readme_template.md', 'r') as f:
        template = f.read()

    # do the same for analysis.md
    with open('analysis.md', 'r') as f:
        analysis = f.read()

    with open('README.md', 'w') as readme:
        readme.write(template)
        readme.write('```yaml \n')
        readme.write(yaml.dump(final_result, allow_unicode=True))
        readme.write('```\n')
        readme.write(analysis)

if __name__ == '__main__':
    generate_readme()
