extends SceneTree

const FLOW_SCENE := preload("res://menus/deployment_flow.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flow := FLOW_SCENE.instantiate()
	root.add_child(flow)
	await process_frame
	var next_button := flow.get_node("UI/Next") as Button
	for expected_stage in [1, 2, 3]:
		next_button.pressed.emit()
		await process_frame
		if expected_stage == 1:
			var video := flow.get_node("UI/MapPreview/VideoStreamPlayer") as VideoStreamPlayer
			var placeholder := flow.get_node("UI/MapPreview/VideoPlaceholder") as ColorRect
			var preview := flow.get_node("UI/MapPreview") as Panel
			assert(video.stream != null and preview.visible and video.is_playing())
			assert(flow.get_node("UI/CardContainer").get_child_count() == 1)
			var first_map_text := (flow.get_node("UI/CardContainer").get_child(0) as Label).text
			(flow.get_node("UI/MapNext") as Button).pressed.emit()
			await process_frame
			assert(flow.get_node("UI/CardContainer").get_child_count() == 1)
			assert((flow.get_node("UI/CardContainer").get_child(0) as Label).text != first_map_text)
			preview.mouse_entered.emit()
			await create_timer(0.25).timeout
			assert(preview.offset_left < -404.0 and not placeholder.visible)
			preview.mouse_exited.emit()
			await create_timer(0.25).timeout
			assert(preview.visible and video.is_playing())
			print("MAP VIDEO OK")
		print("DEPLOYMENT STAGE OK: ", expected_stage)
	var dialogue := flow.get_node("UI/Dialogue") as Label
	assert(dialogue.visible)
	print("DEPLOYMENT POSE OK: ", dialogue.text)
	quit()
