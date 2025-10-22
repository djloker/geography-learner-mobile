extends Node

func compare_string_nocase_nopunc(a: String, b: String) -> bool:
	var a_clean := a.replace('.', '').replace('\'', '').replace(',', '').replace('-', ' ').strip_edges()
	var b_clean := b.replace('.', '').replace('\'', '').replace(',', '').replace('-', ' ').strip_edges()
	return a_clean.nocasecmp_to(b_clean) == 0

## Expects latitude and longitude in RADIANS
func latlong_to_point(latitude: float, longitude: float) -> Vector3:
	return -Vector3(
		cos(latitude)*sin(longitude),
		sin(latitude),
		cos(latitude)*cos(longitude))

func latlong_from_point(point: Vector3) -> Vector2:
	var latitude := -asin(point.y)
	var longitude := -atan2(point.x, -point.z)
	return Vector2(latitude, longitude)

func raw_latlong_to_radians(lat_long: Vector2) -> Vector2:
	return Vector2(lat_long.x * -PI / 180.0, lat_long.y * PI / 180.0)

#static func radian_latlong_to_point(coord: Vector2) -> Vector3:
	#var y := sin(coord.x)
	#var r := cos(coord.x)
	#var x := sin(coord.y) * r
	#var z := -cos(coord.y) * r
	#return Vector3(-x, -y, z)
