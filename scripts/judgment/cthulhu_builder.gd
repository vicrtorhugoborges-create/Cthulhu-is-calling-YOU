class_name CthulhuBuilder
extends RefCounted
## Gera a silhueta de Cthulhu por código (rascunho até existir o modelo do Blender).
##
## Documento de design: malha de até 3.000 triângulos, renderizada em escala de céu,
## com o detalhe concentrado no contorno (tentáculos, asas e garras).
## Unidades em metros. Origem na base do corpo, +Y para cima, de frente para +Z.
##
## Cor do vértice: R = peso do balanço dos tentáculos, G = peso do gesto lento,
## B = brilho dos olhos. O shader shaders/cthulhu.gdshader usa os três.

const MAX_TRIANGLES := 3000

## Altura do topo da cabeça e meia-envergadura das asas (usados pelo Julgamento
## para calcular o cone de visão de modo que ele nunca caiba na tela).
const HEAD_CENTER := Vector3(0, 375, 75)
const WING_HALF_SPAN := 1300.0
const TOP_HEIGHT := 455.0


static func build_body() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tronco curvado para a frente. Começa bem abaixo do platô: ele está de pé
	# no mar atrás da cidadela, e a base nunca cabe no quadro.
	_tube(st, [Vector3(0, -220, -10), Vector3(0, 0, 0), Vector3(0, 120, 5), Vector3(0, 240, 22), Vector3(0, 330, 45)],
		[84.0, 78.0, 72.0, 63.0, 50.0], 8, [0.0, 0.0, 0.0, 0.0, 0.0])
	# Corcunda dos ombros.
	_ellipsoid(st, Vector3(0, 300, 12), Vector3(98, 46, 62), Basis(), 8, 5)
	# Cabeça de polvo, inclinada para a frente como na estatueta.
	var head_basis := Basis(Vector3.RIGHT, deg_to_rad(25.0))
	_ellipsoid(st, HEAD_CENTER, Vector3(55, 74, 60), head_basis, 10, 7)
	# Olhos: dois pontos pálidos.
	for side: float in [-1.0, 1.0]:
		_ellipsoid(st, HEAD_CENTER + head_basis * Vector3(19.0 * side, 6, 56), Vector3(6, 4, 3), head_basis, 5, 3, Color(0, 0, 1))
	# Tentáculos do rosto, pendendo para a frente.
	var count := 10
	for i in count:
		var a := lerpf(-1.1, 1.1, float(i) / float(count - 1))
		var base := HEAD_CENTER + head_basis * Vector3(sin(a) * 34.0, -46, 30 + cos(a) * 18.0)
		var dx := sin(a) * 18.0
		var length := 1.0 + 0.25 * sin(float(i) * 2.3)
		var pts := [
			base,
			base + Vector3(dx * 0.2, -40 * length, 16),
			base + Vector3(dx * 0.4, -90 * length, 26),
			base + Vector3(dx * 0.7, -140 * length, 18),
		]
		var gesture := 1.0 if i == 3 else 0.0
		_tube(st, pts, [10.0, 7.5, 4.5, 1.2], 5, [0.0, 0.45, 0.8, 1.0], gesture)
	# Braços estendidos até o batente da porta (somem atrás da cidadela).
	for side: float in [-1.0, 1.0]:
		_tube(st, [Vector3(82 * side, 300, 30), Vector3(118 * side, 205, 120), Vector3(70 * side, 120, 250)],
			[30.0, 24.0, 17.0], 6, [0.0, 0.05, 0.1])
	# Asas de morcego: cinco nervuras e membrana recortada entre elas.
	for side: float in [-1.0, 1.0]:
		var root := Vector3(62 * side, 325, -22)
		var elbow := Vector3(230 * side, 500, -50)
		var tips: Array[Vector3] = []
		for i in 5:
			tips.append(Vector3(lerpf(300.0, WING_HALF_SPAN, i / 4.0) * side, 580.0 - i * 95.0, -60.0 - i * 25.0))
		for tip in tips:
			_tube(st, [root, elbow, tip], [9.0, 6.0, 1.5], 4, [0.0, 0.08, 0.15])
		for i in 4:
			var mid := root.lerp((tips[i] + tips[i + 1]) * 0.5, 0.72)
			_tri(st, root, tips[i], mid, 0.12)
			_tri(st, root, mid, tips[i + 1], 0.12)
			_tri(st, elbow, tips[i], mid, 0.12)
	st.generate_normals()
	return st.commit()


## Uma mão com quatro garras, para agarrar o batente da porta.
static func build_claw() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(st, Vector3(0, 0, -6), Vector3(16, 8, 20), Basis(), 6, 4)
	for i in 4:
		var x := lerpf(-15.0, 15.0, float(i) / 3.0)
		var spread := x * 0.25
		var start := Vector3(x, 2, 8)
		_tube(st, [start, start + Vector3(spread, 4, 16), start + Vector3(spread * 1.5, -14, 26),
			start + Vector3(spread * 1.8, -34, 22), start + Vector3(spread * 2.0, -46, 12)],
			[5.5, 4.8, 3.8, 2.4, 0.4], 5, [0.0, 0.05, 0.1, 0.15, 0.2])
	# Polegar.
	_tube(st, [Vector3(18, 0, -2), Vector3(26, -4, 8), Vector3(28, -18, 14), Vector3(26, -28, 10)],
		[5.0, 4.0, 2.6, 0.4], 5, [0.0, 0.05, 0.1, 0.15])
	st.generate_normals()
	return st.commit()


static func triangle_count(mesh: ArrayMesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		else:
			total += indices.size() / 3
	return total


# --- Primitivas --------------------------------------------------------------

static func _vertex(st: SurfaceTool, p: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(p)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, sway := 0.0) -> void:
	var col := Color(sway, 0, 0)
	_vertex(st, a, Color(0, 0, 0))
	_vertex(st, b, col)
	_vertex(st, c, col)


## Tubo afunilado ao longo de uma polilinha.
static func _tube(st: SurfaceTool, points: Array, radii: Array, sides: int, sway: Array, gesture := 0.0) -> void:
	var rings: Array = []
	for i in points.size():
		var p: Vector3 = points[i]
		var dir: Vector3
		if i == 0:
			dir = (points[1] - p).normalized()
		elif i == points.size() - 1:
			dir = (p - points[i - 1]).normalized()
		else:
			dir = ((points[i + 1] - p).normalized() + (p - points[i - 1]).normalized()).normalized()
		var helper := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var u := dir.cross(helper).normalized()
		var v := dir.cross(u).normalized()
		var ring: Array[Vector3] = []
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ring.append(p + (u * cos(a) + v * sin(a)) * float(radii[i]))
		rings.append(ring)
	for i in points.size() - 1:
		var c0 := Color(sway[i], gesture * float(i) / float(points.size() - 1), 0)
		var c1 := Color(sway[i + 1], gesture * float(i + 1) / float(points.size() - 1), 0)
		for s in sides:
			var s2 := (s + 1) % sides
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][s2]
			var c: Vector3 = rings[i + 1][s2]
			var d: Vector3 = rings[i + 1][s]
			_vertex(st, a, c0)
			_vertex(st, b, c0)
			_vertex(st, c, c1)
			_vertex(st, a, c0)
			_vertex(st, c, c1)
			_vertex(st, d, c1)


static func _ellipsoid(st: SurfaceTool, center: Vector3, radii: Vector3, basis: Basis, seg_u: int, seg_v: int, color := Color(0, 0, 0)) -> void:
	var grid: Array = []
	for j in seg_v + 1:
		var phi := PI * float(j) / float(seg_v)
		var row: Array[Vector3] = []
		for i in seg_u:
			var theta := TAU * float(i) / float(seg_u)
			var local := Vector3(sin(phi) * cos(theta) * radii.x, cos(phi) * radii.y, sin(phi) * sin(theta) * radii.z)
			row.append(center + basis * local)
		grid.append(row)
	for j in seg_v:
		for i in seg_u:
			var i2 := (i + 1) % seg_u
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i2]
			var c: Vector3 = grid[j + 1][i2]
			var d: Vector3 = grid[j + 1][i]
			if j > 0:
				_vertex(st, a, color)
				_vertex(st, b, color)
				_vertex(st, c, color)
			if j < seg_v - 1:
				_vertex(st, a, color)
				_vertex(st, c, color)
				_vertex(st, d, color)
