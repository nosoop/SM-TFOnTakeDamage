#!/usr/bin/python3

import dissect.cstruct
import dissect.cstruct.types.base
import chevron
import pathlib
import argparse

def transform_class_definition(data):
	# given a parsed dissect.cstruct.types.structure.Structure,
	# returns a dict appropriate for the class definition template
	
	# type mappings: 'c_type' -> ('sp_type', 'NumberType')
	type_mapping = {
		'int32': ('int', 'NumberType_Int32'),
		'uint8': ('bool', 'NumberType_Int8'),
	}
	
	output = {
		'classname': data.name,
		'size': len(data),
		'properties': [],
		'decl_variables': [],
		'array_type_defs': [],
	}
	
	array_type_defs = {}
	
	for field in filter(lambda f: f.name != '__padding', data.fields):
		var_ref_name = f'offs_{data.name}_{field.name}'
		
		# provide every class name as a variable in case we'd like to import it from gamedata
		output['decl_variables'].append({
			'var': var_ref_name,
			'assign': str(field.offset),
		})
		
		property = {
			'name': field.name,
			'offset': var_ref_name,
			'writable': True,
		}
		
		if isinstance(field.type, dissect.cstruct.types.pointer.Pointer):
			actual_type = field.type.type.name
			property.update({
				'size': 'NumberType_Int32',
				'type': actual_type if actual_type != 'void' else 'Address',
			})
		# TODO if struct it should be treated as inline
		elif isinstance(field.type, dissect.cstruct.types.base.RawType):
			alias_type, mem_size = type_mapping.get(field.type.name, (field.type.name, 'NumberType_Int32'))
			
			property.update({
				'size': mem_size,
				'type': alias_type,
			})
		elif isinstance(field.type, dissect.cstruct.types.base.Array):
			# if it's an array, generate a wrapper for the type / size
			# this allows us the class member as a property with getter / setter methods,
			# as well as reuse methods for similar arrays (such as the common `float[3]`)
			field_array = field.type
			alias_type, mem_size = type_mapping.get(
				field_array.type.name,
				(field_array.type.name, 'NumberType_Int32')
			)
			
			array_type_internal_name = f'IMPL_internal_method_array_{alias_type}{field.type.count}'
			property.update({
				'type': array_type_internal_name,
				'inline': True,
			})
			
			# store unique copies of arrays with internal name
			array_type_defs[array_type_internal_name] = {
				'name': array_type_internal_name,
				'type': alias_type,
				'count': field.type.count,
				'size': mem_size,
				'stride': len(field_array.type),
			}
		
		output['properties'].append(property)
	output['array_type_defs'] = list(array_type_defs.values())
	
	return output

if __name__ == '__main__':
	parser = argparse.ArgumentParser(
			description = "Takes a Mustache template and some data and generates an output file")
	
	parser.add_argument('template', help = "Template to use", type = pathlib.Path)
	parser.add_argument('definition', help = "Definitions to parse", type = pathlib.Path)
	parser.add_argument('type', help = "Type to extract")
	parser.add_argument('output', help = "Output file", type = pathlib.Path)
	
	args = parser.parse_args()
	
	with args.template.open('rt') as f, args.definition.open('rt') as d:
		template = f.read()
		
		cparser = dissect.cstruct.cstruct(pointer = 'uint32', align = True)
		cparser.load(d.read())
		
		result = chevron.render(template, transform_class_definition(cparser.typedefs[args.type]))
		with args.output.open('wt') as g:
			g.write(result)
