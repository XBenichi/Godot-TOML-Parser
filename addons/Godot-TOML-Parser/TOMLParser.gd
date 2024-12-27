extends Node

class_name TOMLParser

var parsed_data = {}
var multi_line = false

func parse(toml_path):
	var toml_file = File.new()
	
	if toml_file.file_exists(toml_path):
		toml_file.open(toml_path, File.READ)
		var toml_content = toml_file.get_as_text()
		toml_file.close()
		
		var json_data = toml_to_json(toml_content)
		return json_data
	else:
		push_error("TOML file not found: %s" % toml_path)
		return "{}"


func toml_to_json(toml_string: String):
	parsed_data.clear()
	var lines = toml_string.strip_edges().split("\n")
	var current_table = null
	var current_array_table = null
	var multi_line_mode = "String"
	
	
	for line in lines:
		line = strip_inline_comments(line.strip_edges())
		if line.empty():
			continue
		
		if line.begins_with("[[") and line.ends_with("]]"):
			# array of tables
			current_table = null
			current_array_table = parse_array_table(line)
		elif line.begins_with("[") and line.ends_with("]"):
			# regular table definition
			current_array_table = null
			current_table = parse_table(line)
		elif multi_line == true:
			
			var table = parsed_data
			
			
			var updated_line = line
			
			if "'''" in updated_line or "\"\"\"" in updated_line:
				updated_line.replace("'''","")
				updated_line.replace("\"\"\"","")
				multi_line = false
			
			if multi_line_mode == "String":
				if table[table.keys()[-1]] == null:
					table[table.keys()[-1]] = ""
				table[table.keys()[-1]] = table[table.keys()[-1]] + updated_line + "\n"
				
			
		else:
			var key_value = parse_key_value(line)
			var key = key_value[0]
			var value = key_value[1]
			var keys = []
			var temp = {}
			
			if "." in key:
				keys = key.split(".")
				
				keys.invert()
				
				for i in keys:
					if temp.empty():
						temp[i] = value
					else: 
						temp[i] = {} 
						if typeof(temp[temp.keys()[0]]) == TYPE_STRING:
							temp[i][temp.keys()[0]] = temp[temp.keys()[0]]
						else:
							temp[i][temp.keys()[0]] = temp[temp.keys()[0]].duplicate()
						temp.erase(temp.keys()[0])
				
				key = temp.duplicate()
				
			
			
			
			if current_array_table:
				insert_into_array_table(current_array_table, key, value)
			elif current_table:
				insert_into_table(current_table, key, value)
			else:
				if key in parsed_data:
					raise_error("Duplicate top-level key '%s'" % key)
				
				if typeof(key) == TYPE_STRING:
					parsed_data[key] = value
				elif typeof(key) == TYPE_DICTIONARY:
					var root_key = key.keys()[0]
					if root_key in parsed_data:
						if typeof(parsed_data[root_key]) == TYPE_DICTIONARY and typeof(key[root_key]) == TYPE_DICTIONARY:
							merge_dictionaries(parsed_data[root_key], key[root_key])
						else:
							raise_error("Key conflict at '%s'" % root_key)
					else:
						parsed_data[root_key] = key[root_key].duplicate()
	
	multi_line = false
	return parsed_data


func merge_dictionaries(target: Dictionary, source: Dictionary):
	for k in source.keys():
		if k in target and typeof(target[k]) == TYPE_DICTIONARY and typeof(source[k]) == TYPE_DICTIONARY:
			merge_dictionaries(target[k], source[k])
		else:
			target[k] = source[k].duplicate() if typeof(source[k]) == TYPE_DICTIONARY else source[k]

func parse_table(line: String):
	var table_name = line.substr(1, line.length() - 2).strip_edges()
	if table_name.empty():
		raise_error("Invalid table name: '%s'" % line)
	
	var keys = table_name.split(".")
	var current = parsed_data
	for key in keys:
		if !key in current:
			current[key] = {}
		elif typeof(current[key]) != TYPE_DICTIONARY:
			raise_error("Conflict with existing key: '%s'" % key)
		current = current[key]
	return table_name


func parse_array_table(line: String):
	var array_table_name = line.substr(2, line.length() - 4).strip_edges()
	if array_table_name.empty():
		raise_error("Invalid array table name: '%s'" % line)
	
	var keys = array_table_name.split(".")
	var current = parsed_data
	for key in keys:
		if !key in current:
			current[key] = []
		elif typeof(current[key]) != TYPE_ARRAY:
			raise_error("Conflict with existing key: '%s'" % key)
		current = current[key]
	
	current.append({})
	return array_table_name


func parse_key_value(line: String):
	var split_index = line.find("=")
	if split_index == -1:
		raise_error("Invalid key-value pair: '%s'" % line)
	
	var key = line.substr(0, split_index).strip_edges()
	var value = parse_value(line.substr(split_index + 1).strip_edges())
	
	if typeof(value) == TYPE_STRING:
		value = value.replace("\\n","\n")
		value = value.replace("\\t","\t")
		value = value.replace("\\b","\b")
		value = value.replace("\\f","\f")
		value = value.replace("\\r","\r")
		value = value.replace('\\"','\"')
	
	
	
	return [key, value]


func parse_value(value: String):
	if value.begins_with("\"\"\"") or value.begins_with("'''"):  # multi-line string
		multi_line = !multi_line
	elif value.begins_with("\"") and value.ends_with("\"") or value.begins_with("\'") and value.ends_with("\'"):  # single-line string
		return value.substr(1, value.length() - 2)
	elif value.begins_with("[") and value.ends_with("]"):  # array
		return parse_array(value.substr(1, value.length() - 2))
	elif value.begins_with("{") and value.ends_with("}"):  # inline table
		return parse_inline_table(value.substr(1, value.length() - 2))
	elif value.is_valid_integer():
		return int(value)
	elif value.is_valid_float():
		return float(value)
	elif value == "true" or value == "false":
		return value == "true"
	elif value.find("T") != -1 or value.find("Z") != -1:
		return parse_datetime(value)
	elif value in ["inf","+inf","-inf","nan","+nan","-nan"]:
		if "inf" in value:
			if "-" in value:
				return INF * -1 
			return INF
		elif "nan" in value:
			if "-" in value:
				return -NAN
			return NAN
			
	elif "_" in value or "E" in value:
		value = value.replace("_","")
		value = value.replace("E","e")
		
		return parse_value(value)
	elif value.is_valid_hex_number(true):
		return value.hex_to_int()
		
	else:
		raise_error("Unknown value type: '%s'" % value)
	return null



func parse_inline_table(inline_table_string: String):
	var result = {}
	var key_value_pairs = []
	var current_pair = ""
	var open_brackets = 0
	
	
	for chara in inline_table_string:
		if chara == "[" or chara == "{":
			open_brackets += 1
		elif chara == "]" or chara == "}":
			open_brackets -= 1
		
		if chara == "," and open_brackets == 0:
			key_value_pairs.append(current_pair.strip_edges())
			current_pair = ""
		else:
			current_pair += chara
	
	if current_pair.strip_edges() != "":
		key_value_pairs.append(current_pair.strip_edges())
	
	for pair in key_value_pairs:
		var split_index = pair.find("=")
		if split_index == -1:
			raise_error("Invalid inline table entry: '%s'" % pair)
		
		var key = pair.substr(0, split_index).strip_edges()
		var value = parse_value(pair.substr(split_index + 1).strip_edges())
		var keys = []
		var temp = {}
		
		if "." in key:
			keys = key.split(".")
			
			keys.invert()
			
			for i in keys:
				if temp.empty():
					temp[i] = value
				else: 
					temp[i] = {} 
					if typeof(temp[temp.keys()[0]]) == TYPE_STRING:
						temp[i][temp.keys()[0]] = temp[temp.keys()[0]]
					else:
						temp[i][temp.keys()[0]] = temp[temp.keys()[0]].duplicate()
					temp.erase(temp.keys()[0])
			
			key = temp.duplicate()
			
			if typeof(key) == TYPE_STRING:
				result[key] = value
			elif typeof(key) == TYPE_DICTIONARY:
				var root_key = key.keys()[0]
				if root_key in result:
					if typeof(result[root_key]) == TYPE_DICTIONARY and typeof(key[root_key]) == TYPE_DICTIONARY:
						merge_dictionaries(result[root_key], key[root_key])
					else:
						raise_error("Key conflict at '%s'" % root_key)
				else:
					result[root_key] = key[root_key].duplicate()
	
	
	return result




func parse_array(array_string: String):
	var items = array_string.split(",")
	var result = []
	for item in items:
		result.append(parse_value(item.strip_edges()))
	return result


func parse_datetime(datetime_string: String):
	var datetime_regex = RegEx.new()
	datetime_regex.compile("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:Z|[-+]\\d{2}:\\d{2})$")
	if not datetime_regex.search(datetime_string):
		raise_error("Invalid datetime format: '%s'" % datetime_string)
	return datetime_string


func insert_into_table(table_name: String, key: String, value):
	var keys = table_name.split(".")
	var current = parsed_data
	for sub_key in keys:
		current = current[sub_key]
	
	if key in current:
		raise_error("Duplicate key '%s' in table '%s'" % [key, table_name])
	current[key] = value


func insert_into_array_table(array_table_name: String, key: String, value):
	var keys = array_table_name.split(".")
	var current = parsed_data
	for sub_key in keys:
		current = current[sub_key]
	
	if typeof(current) != TYPE_ARRAY:
		raise_error("Array table '%s' is not an array!" % array_table_name)
	
	current[-1][key] = value

func strip_inline_comments(line: String):
	var comment_index = line.find("#")
	if comment_index != -1:
		return line.substr(0, comment_index).strip_edges()
	return line

func raise_error(message: String):
	printerr(message)
	push_error(message)
#	assert(false, message)

func print_pretty_json(data):
	var json_string = JSON.print(data, "\t")
	print(json_string)
