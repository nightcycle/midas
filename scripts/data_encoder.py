import hashlib
import toml
import base64
import json
import os
import io
	
CONFIG = toml.load("./midas.toml")
ENCODING_CONFIG = CONFIG["encoding"]
ENCODING_DICT = ENCODING_CONFIG["dictionary"]
ENCODING_PROPERTY_DICT = ENCODING_DICT["properties"]
ENCODING_VALUE_DICT = ENCODING_DICT["values"]
ENCODING_ARRAYS = ENCODING_CONFIG["arrays"]
ENCODING_MARKER = ENCODING_CONFIG["marker"]

def encode(full_data: dict[str, any]):

	def replace_keys(data: dict[str, any]):
		# return data
		out = {}
		for k in data:
			k = k.replace(ENCODING_MARKER, "")
			v = data[k]
			if type(v) == dict:
				v = replace_keys(v)

			if k in ENCODING_PROPERTY_DICT:
				out[ENCODING_MARKER + ENCODING_PROPERTY_DICT[k]] = v
			else:
				out[k] = v

		return out

	def replace_binary_list(data: dict[str, any], bin_array: list[str]):
		encoded_str = ENCODING_MARKER + ""
		for item in bin_array:
			v = "0"
			if item in data:
				if data[item] == True:
					v = "1"

			encoded_str += v
		return encoded_str

	def replace_values(data: dict[str, any], val_dict: dict[str: any], bin_array_reg: dict[str, any]):
		out = {}

		for k in data:
			nxt_bin_array_reg = {}
			if k in bin_array_reg:
				nxt_bin_array_reg = bin_array_reg[k]

			v = data[k]
			if type(v) == str:
				v = v.replace(ENCODING_MARKER, "")

			if k in val_dict:
				if type(v) == dict:
					if type(nxt_bin_array_reg) == list:
						v = replace_binary_list(v, nxt_bin_array_reg)
					else:
						v = replace_values(v, val_dict[k], nxt_bin_array_reg)
				else:
					if v in val_dict[k]:
						v = ENCODING_MARKER + val_dict[k][v]
							
			else:
				if type(v) == dict:
					if type(nxt_bin_array_reg) == list:
						v = replace_binary_list(v, nxt_bin_array_reg)
					else:
						v = replace_values(v, {}, nxt_bin_array_reg)

			out[k] = v

		return out

	return replace_keys(replace_values(full_data, ENCODING_VALUE_DICT, ENCODING_ARRAYS))

def decode(encoded_data: dict[str, any]):

	def restore_keys(data: dict[str, any]):
		out = {}
		for k in data:
			v = data[k]
			if type(v) == dict:
				v = restore_keys(v)

			decoded_key = k
			if k.startswith(ENCODING_MARKER):
				for original_key, encoded_key in ENCODING_PROPERTY_DICT.items():
					if k == ENCODING_MARKER + encoded_key:
						decoded_key = original_key
						break

			out[decoded_key] = v

		return out

	def restore_binary_list(encoded_str: str, bin_array: list[str]):
		restored_data = {}
		for i, key in enumerate(bin_array):
			v = encoded_str[i+len(ENCODING_MARKER)]
			if v == "1":
				restored_data[key] = True
			else:
				restored_data[key] = False
					
		return restored_data

	def restore_values(data: dict[str, any], val_dict: dict[str: any], bin_array_reg: dict[str, any]):
		out = {}

		for k in data:
			nxt_bin_array_reg = {}
			if k in bin_array_reg:
				nxt_bin_array_reg = bin_array_reg[k]

			v = data[k]
			if type(v) == dict:
				if k in val_dict:
					v = restore_values(v, val_dict[k], nxt_bin_array_reg)
				else:
					v = restore_values(v, {}, nxt_bin_array_reg)
			else:
				if type(v) == str:
					if ENCODING_MARKER in v:
						if type(nxt_bin_array_reg) == list:
							v = restore_binary_list(v, nxt_bin_array_reg)
						elif k in val_dict:
							for orig_v in val_dict[k]:
								alt_v = val_dict[k][orig_v]
								if v == alt_v:
									v = orig_v

			out[k] = v

		return out

	return restore_values(restore_keys(encoded_data), ENCODING_VALUE_DICT, ENCODING_ARRAYS)

def test():
	TEST_IN = "example/event_sample.json"
	TEST_OUT = "example/encode_sample.json"
	TEST_REVERT = "example/decode_sampe.json"

	if os.path.exists(TEST_REVERT):
		os.remove(TEST_REVERT)

	if os.path.exists(TEST_OUT):
		os.remove(TEST_OUT)
		
	event_sample = json.load(open(TEST_IN, "r"))
	encode_sample = encode(event_sample)
	decode_sample = decode(encode_sample)

	encode_file = open(TEST_OUT, "w")
	encode_file.write(json.dumps(encode_sample, separators=(',', ':')))
	encode_file.close()

	revert_file = open(TEST_REVERT, "w")
	revert_file.write(json.dumps(decode_sample,indent=4))
	revert_file.close()

	start_size = os.path.getsize(TEST_IN)
	finish_size = os.path.getsize(TEST_OUT)
	print("Reduction of", start_size, "to" , finish_size, "bytes (", round(1000*(1-finish_size/start_size))/10, "%", "reduction)")
