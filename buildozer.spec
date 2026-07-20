[app]

# (str) Título de la app tal como aparece en el celular
title = Tukyliano

# (str) Nombre del paquete (sin espacios ni mayúsculas)
package.name = tukyliano

# (str) Dominio del paquete (al revés, estilo Java) - podés inventar uno
package.domain = org.gmatiascr62

# (str) Directorio donde está el código fuente (donde vive main.py)
source.dir = .

# (list) Extensiones de archivo a incluir del código fuente
source.include_exts = py,png,jpg,kv,atlas,json

# (str) Versión de la app
version = 1.0

# (list) Requerimientos de Python que necesita la app.
# urllib, json, threading, shutil, random y os son de la librería estándar,
# no hace falta listarlos acá. Solo python3 y kivy.
requirements = python3,kivy

# (str) Orientación de la app: portrait, landscape, o all
orientation = portrait

# (bool) Pantalla completa (sin barra de notificaciones)
fullscreen = 0

# (list) Permisos de Android que necesita la app.
# INTERNET es imprescindible para que baje el data.json de GitHub.
android.permissions = INTERNET

# (int) API mínima de Android que soporta la app
android.minapi = 21

# (str) Ícono de la app - PNG cuadrado, se recomienda 512x512
icon.filename = %(source.dir)s/icon.png

# (str) Imagen de presplash (pantalla que se ve mientras carga la app)
presplash.filename = %(source.dir)s/presplash.png

[buildozer]

# (int) Nivel de detalle del log (0 = solo error, 1 = info, 2 = debug)
log_level = 2

# (int) Mostrar advertencia si se corre como root (normal en Colab)
warn_on_root = 0
