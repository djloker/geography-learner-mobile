# country_list.gd
class_name CountryList extends Resource

@export var countries: Array[CountryResource]

var size:
	get: return len(countries)
