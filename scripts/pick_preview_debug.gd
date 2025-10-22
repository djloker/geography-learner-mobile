extends TextureRect


func _on_camera_3d_country_selected(UV: Vector2) -> void:
	$ColorRect.position.x = UV.x * size.x
	$ColorRect.position.y = UV.y * size.y
