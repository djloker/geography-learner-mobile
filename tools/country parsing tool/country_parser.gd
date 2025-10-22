extends Node

@export_file("*.txt") var countries_base_data
@export_file("*.txt") var countries_addendum
@export_dir var output_path: String

class CountryMetaData:
	var polygons: Array[PolygonMetaData]
	
	func largest_poly() -> PolygonMetaData:
		var largest := polygons[0]
		for i in range(1, len(polygons)):
			if polygons[i].bbox_area() > largest.bbox_area():
				largest = polygons[i]
		return largest

class PolygonMetaData:
	var start_index: int
	var count: int
	var bbox: Vector4
	
	func bbox_width() -> float: return abs(bbox.z - bbox.x)
	func bbox_height() -> float: return abs(bbox.w - bbox.y)
	func bbox_area() -> float: return bbox_width() * bbox_height()
	func bbox_centroid() -> Vector2: # returns Latitude/Longitude order
		return Vector2(bbox.y + bbox_height()/2.0, bbox.x + bbox_width()/2.0)

	# Lambda to load a polygon, since it's the same between 'MultiPolygon' and
	# 'Polygon' dictionaries. Good job not repeating yourself, champ.
func load_polygon(i: int, poly: Array, country: CountryMetaData):
	var metadata := PolygonMetaData.new()
	metadata.start_index = i
	metadata.bbox = Vector4(INF, INF, -INF, -INF)
	for point in poly:
		#if i > metadata.start_index: # complete line, except at loop start
			#indices.append(i)
		var vert := Vector3(point[0], point[1], 0.0)
		#verts.append(vert)
		metadata.bbox[0] = min(metadata.bbox[0], vert.x)
		metadata.bbox[1] = min(metadata.bbox[1], vert.y)
		metadata.bbox[2] = max(metadata.bbox[2], vert.x)
		metadata.bbox[3] = max(metadata.bbox[3], vert.y)
		i += 1
	metadata.count = i - metadata.start_index
	country.polygons.append(metadata)
	#indices.append(metadata.start_index) # close the loop
	return i

func read_country(country_dict: Dictionary) -> CountryResource:
	var country := CountryResource.new()
	country.name = country_dict.properties['NAME']
	country.code = country_dict.properties['2_LETTER_CODE']
	
	var index := 0
	var country_meta := CountryMetaData.new()
	if country_dict.geometry.type == 'MultiPolygon':
		for multipoly in country_dict.geometry.coordinates:
			for poly in multipoly:
				index = load_polygon(index, poly, country_meta)
	else:
		assert(country_dict.geometry.type == 'Polygon')
		for poly in country_dict.geometry.coordinates:
			index = load_polygon(index, poly, country_meta)
	country.centroid = country_meta.largest_poly().bbox_centroid()
	print("%d: %s (%s) - polys %d - (centroid: %.1f, %.1f)" % [
		index,
		country.name,
		country.code,
		len(country_meta.polygons),
		country.centroid.x,
		country.centroid.y
	])
	
	return country

func read_all_countries() -> void:
	if not FileAccess.file_exists(countries_base_data):
		printerr("Cannot open '%s': does not exist." % countries_base_data)
		return
	var all_countries := CountryList.new()
	var json := JSON.new()
	var f := FileAccess.open(countries_base_data, FileAccess.READ)
	# Skip header lines
	var error := json.parse(f.get_as_text())
	if error != OK:
		printerr(json.get_error_message())
		f.close()
		return
	
	var data_received = json.data
	# 'features' contains every country
	for feature in data_received.features:
		all_countries.countries.append(read_country(feature))
	f.close()
	
	if FileAccess.file_exists(countries_addendum):
		print('Reading in addendum file (%s)' % countries_addendum)
		f = FileAccess.open(countries_addendum, FileAccess.READ)
		if json.parse(f.get_as_text()) == OK:
			data_received = json.data
			for country in all_countries.countries:
				if country.name in data_received:
					print('Getting additional data for ', country.name)
					country.capital = data_received[country.name].capital
					for alt_name in data_received[country.name].alt_names:
						country.alt_names.append(alt_name)
		else: printerr(json.get_error_message())
		f.close()
	
	print('Saving all_countries.tres')
	ResourceSaver.save(all_countries, output_path.path_join("all_countries.tres"), ResourceSaver.FLAG_COMPRESS)

func _on_load_button_pressed() -> void:
	read_all_countries()
