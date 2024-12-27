

# Godot TOML Parser

Godot TOML Parser is a Godot 3.x addon that parses TOML files into something that Godot can read.

## Usage

```gdscript

var toml = TOMLParser.new() # Define the parser in your script

var file = toml.parse("res://file.toml") # Load your TOML file from a specified path

# After this, usage is exactly like JSON

print(file["variable"])

```

## List of currently known issues

- Octal and binary numbers aren't supported
- Complex Date-time (eg. 1979-05-27T00:32:00.999999-07:00) isn't valid
- Local date-time and seperate date and time aren't supported
- sub-tables such as "[fruits.physical]" and "[[fruits.varieties]]"; and multi-lined arrays aren't supported
