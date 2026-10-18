extends Button

# Keep this reference alive so JavaScript can call back into Godot.
var file_callback: JavaScriptObject
@onready var predator : Node2D = get_tree().get_first_node_in_group("predator")
@onready var body_sprite : Sprite2D = predator.get_node("Visuals/Sprite2D")

func _ready() -> void:
	pressed.connect(_on_pressed)

	if OS.has_feature("web"):
		file_callback = JavaScriptBridge.create_callback(_on_file_selected)


func _on_pressed() -> void:
	if not OS.has_feature("web"):
		print("Test the image picker in the browser export.")
		return

	var browser_window = JavaScriptBridge.get_interface("window")
	browser_window.godot_image_selected = file_callback

	JavaScriptBridge.eval("""
		const picker = document.createElement("input");
		picker.type = "file";
		picker.accept = "image/png";

		picker.addEventListener("change", async () => {
			const file = picker.files[0];
			if (!file) return;

			const buffer = await file.arrayBuffer();
			window.godot_image_selected(buffer, file.name);
		});

		picker.click();
	""")


func _on_file_selected(arguments: Array) -> void:
	var bytes := JavaScriptBridge.js_buffer_to_packed_byte_array(
		arguments[0]
	)
	var file_name: String = arguments[1]

	var image := Image.new()
	var error := image.load_png_from_buffer(bytes)

	if error != OK:
		push_error("Could not load this file as a PNG.")
		return

	print("Selected image: ", file_name)
	print("Image dimensions: ", image.get_size())
	
	var texture := ImageTexture.create_from_image(image)
	body_sprite.texture = texture
