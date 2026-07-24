import json
import os
import shutil
import threading
import traceback
import random
import webbrowser

import requests

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.checkbox import CheckBox
from kivy.uix.scrollview import ScrollView
from kivy.uix.textinput import TextInput
from kivy.uix.screenmanager import ScreenManager, Screen, NoTransition
from kivy.core.window import Window
from kivy.metrics import dp, sp
from kivy.graphics import Color, Rectangle
from kivy.clock import Clock

Window.clearcolor = (0.95, 0.95, 0.95, 1)

# En Android, el modo por defecto ("resize") a veces no restaura bien el
# tamaño de la ventana cuando se cierra el teclado nativo (bug conocido de
# Kivy), dejando un espacio en blanco arriba para siempre. Con "below_target"
# la ventana nunca cambia de tamaño, solo se desplaza para mostrar el campo
# enfocado arriba del teclado, así no hay nada que restaurar mal.
Window.softinput_mode = "below_target"

# JSON que viene empaquetado con la app (versión de respaldo, por si no hay internet)
RUTA_JSON_DEFAULT = os.path.join(os.path.dirname(__file__), "verbos.json")

# JSON en GitHub que se chequea para ver si hay verbos nuevos
URL_REMOTO = "https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/data.json"

PLACEHOLDER = "Escribí la conjugación..."

# Filas del teclado personalizado
FILAS_TECLADO = [
    list("qwertyuiop"),
    list("asdfghjkl"),
    list("zxcvbnm") + ["<--"],
    list("àèéìòù"),
]

# Tiempos verbales que se pueden practicar
TIEMPOS_DISPONIBLES = ["presente", "passato_prossimo", "imperfetto", "futuro_semplice"]
ETIQUETAS_TIEMPO = {
    "presente": "presente",
    "passato_prossimo": "passato prossimo",
    "imperfetto": "imperfetto",
    "futuro_semplice": "futuro semplice",
}

# IA que genera y corrige las frases de la pantalla "Frases" (Gemini, gratis).
# La clave NUNCA se guarda en el código: la pide la app y la guarda en el
# celular la primera vez que se usa "Frases" (ver PantallaClaveIA).
# Se usa el modelo "lite": gemini-2.5-flash tiene cuota gratis de solo
# 20 pedidos/día por proyecto, mientras que el lite tiene una cuota aparte
# mucho más alta.
GEMINI_MODEL = "gemini-flash-lite-latest"
URL_GEMINI = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
URL_GEMINI_API_KEY = "https://aistudio.google.com/apikey"


def abrir_url(url):
    """Abre una URL en el navegador. En Android usa un Intent nativo porque
    el módulo webbrowser de Python no sabe abrir nada ahí; en escritorio usa
    el webbrowser normal."""
    try:
        from jnius import autoclass

        Intent = autoclass("android.content.Intent")
        Uri = autoclass("android.net.Uri")
        PythonActivity = autoclass("org.kivy.android.PythonActivity")
        intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        PythonActivity.mActivity.startActivity(intent)
    except Exception:
        webbrowser.open(url)


class ClaveInvalidaError(Exception):
    """La clave de Gemini no existe, es inválida o fue revocada."""


def preguntar_gemini(prompt, api_key):
    """Manda un prompt a Gemini y devuelve el texto de la respuesta."""
    r = requests.post(
        URL_GEMINI,
        params={"key": api_key},
        json={
            "contents": [{"parts": [{"text": prompt}]}],
        },
        timeout=20,
    )
    if r.status_code in (400, 403):
        raise ClaveInvalidaError(r.text)
    r.raise_for_status()
    datos = r.json()
    return datos["candidates"][0]["content"]["parts"][0]["text"]


def extraer_json(texto):
    """Gemini a veces envuelve el JSON en ```json ... ``` u otro texto alrededor."""
    inicio = texto.find("{")
    fin = texto.rfind("}")
    if inicio == -1 or fin == -1:
        raise ValueError(f"No se encontró JSON en la respuesta: {texto!r}")
    return json.loads(texto[inicio:fin + 1])


def generar_frase(verbo, traduccion, tiempo, persona, api_key):
    """Le pide a Gemini una oración corta en español que se traduzca al
    italiano usando el verbo/tiempo/persona dados. Devuelve (espanol, italiano)."""
    etiqueta_tiempo = ETIQUETAS_TIEMPO.get(tiempo, tiempo)
    prompt = (
        f"Generá una oración MUY CORTA en español (máximo 6 palabras), natural, "
        f"que se traduzca al italiano usando el verbo '{verbo}' ({traduccion}) "
        f"conjugado en {etiqueta_tiempo}, persona '{persona}'. "
        f"Usá español de Latinoamérica: 'ustedes', nunca 'vosotros'. "
        f'Respondé SOLO un JSON válido, sin markdown, con este formato exacto: '
        f'{{"espanol": "...", "italiano": "..."}}'
    )
    datos = extraer_json(preguntar_gemini(prompt, api_key))
    return datos["espanol"], datos["italiano"]


def verificar_frase(frase_es, italiano_referencia, respuesta_usuario, api_key):
    """Le pregunta a Gemini si la traducción del usuario es válida (acepta
    variantes correctas, no exige que sea idéntica a la referencia)."""
    prompt = (
        f'Frase en español: "{frase_es}"\n'
        f'Traducción de referencia al italiano: "{italiano_referencia}"\n'
        f'Respuesta del alumno: "{respuesta_usuario}"\n\n'
        f"¿Es una traducción correcta al italiano (aceptando variantes válidas, "
        f"no tiene que ser idéntica a la referencia, pero ojo con errores de "
        f"tipeo)? Respondé SOLO la palabra CORRECTO o INCORRECTO."
    )
    texto = preguntar_gemini(prompt, api_key).strip().upper()
    return texto.startswith("CORRECTO")


def elegir_combo_azar(verbos, tiempos):
    """Elige verbo, tiempo y persona al azar, entre los que tengan datos
    cargados para alguno de los tiempos pedidos."""
    verbos_validos = [
        v for v, datos in verbos.items()
        if any(t in datos.get("tiempos", {}) for t in tiempos)
    ]
    if not verbos_validos:
        return None, None, None

    verbo = random.choice(verbos_validos)
    tiempos_verbo = [t for t in tiempos if t in verbos[verbo]["tiempos"]]
    tiempo = random.choice(tiempos_verbo)
    persona = random.choice(list(verbos[verbo]["tiempos"][tiempo].keys()))
    return verbo, tiempo, persona


def aplicar_tecla(texto_actual, tecla):
    """Devuelve el texto actualizado después de tocar una tecla del teclado
    personalizado (letra, espacio o borrar)."""
    if tecla == "<--":
        return texto_actual[:-1]
    if tecla == "espacio":
        return texto_actual + " "
    return texto_actual + tecla


def crear_teclado(on_tecla):
    """Arma el teclado personalizado (letras + acentos + espacio + borrar).
    on_tecla(tecla: str) se llama con el texto de la tecla tocada."""
    contenedor = BoxLayout(
        orientation="vertical",
        spacing=dp(6),
        size_hint=(1, None),
    )
    alto_tecla = dp(52)
    total_filas = len(FILAS_TECLADO) + 1  # +1 por la fila del espacio
    contenedor.height = alto_tecla * total_filas + dp(6) * (total_filas - 1)

    for fila in FILAS_TECLADO:
        fila_layout = BoxLayout(
            orientation="horizontal",
            spacing=dp(4),
            size_hint=(1, None),
            height=alto_tecla,
        )
        for tecla in fila:
            boton = Button(
                text=tecla,
                font_size=sp(18) if tecla == "<--" else sp(20),
            )
            boton.bind(on_press=lambda inst: on_tecla(inst.text))
            fila_layout.add_widget(boton)
        contenedor.add_widget(fila_layout)

    fila_espacio = BoxLayout(
        orientation="horizontal",
        size_hint=(1, None),
        height=alto_tecla,
    )
    boton_espacio = Button(text="espacio", font_size=sp(18))
    boton_espacio.bind(on_press=lambda inst: on_tecla("espacio"))
    fila_espacio.add_widget(boton_espacio)
    contenedor.add_widget(fila_espacio)

    return contenedor


def crear_fila_botones_top(ir_a_articoli, ir_a_frases, ir_a_verbos):
    """Fila de navegación (Articoli / Frases / Verbos) que se repite arriba
    de varias pantallas."""
    fila = BoxLayout(orientation="horizontal", size_hint=(1, None), height=dp(50))

    boton_articoli = Button(text="Articoli", font_size=sp(16))
    boton_articoli.bind(on_press=lambda *a: ir_a_articoli())
    fila.add_widget(boton_articoli)

    boton_frases = Button(text="Frases", font_size=sp(16))
    boton_frases.bind(on_press=lambda *a: ir_a_frases())
    fila.add_widget(boton_frases)

    boton_verbos = Button(text="Verbos", font_size=sp(16))
    boton_verbos.bind(on_press=lambda *a: ir_a_verbos())
    fila.add_widget(boton_verbos)

    return fila


class CampoTexto(Label):
    """Label que simula un campo de texto, con fondo blanco."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        with self.canvas.before:
            Color(1, 1, 1, 1)
            self.rect = Rectangle(pos=self.pos, size=self.size)
        self.bind(pos=self._actualizar_rect, size=self._actualizar_rect)

    def _actualizar_rect(self, *args):
        self.rect.pos = self.pos
        self.rect.size = self.size


class QuizVerbos(BoxLayout):
    """Widget del quiz en sí. Recibe el diccionario de verbos a usar."""

    def __init__(self, verbos, tiempos_seleccionados, **kwargs):
        super().__init__(orientation="vertical", padding=dp(14), spacing=dp(8), **kwargs)

        self.verbos = verbos
        self.tiempos_seleccionados = tiempos_seleccionados
        self.puntaje = 0
        self.total = 0
        self.respuesta_correcta = ""
        self.texto_actual = ""
        self.modo = "verificar"

        # Puntaje
        self.label_puntaje = Label(
            text="Puntaje: 0/0",
            font_size=sp(16),
            size_hint=(1, None),
            height=dp(40),
            color=(0.2, 0.2, 0.2, 1),
        )
        self.add_widget(self.label_puntaje)

        # Pregunta
        self.label_pregunta = Label(
            text="",
            font_size=sp(16),
            size_hint=(1, None),
            height=dp(130),
            color=(0.1, 0.1, 0.4, 1),
            halign="center",
            valign="middle",
        )
        self.label_pregunta.bind(size=self._actualizar_text_size)
        self.add_widget(self.label_pregunta)

        # Campo de texto (Label que actúa como input)
        self.campo_texto = CampoTexto(
            text=PLACEHOLDER,
            font_size=sp(22),
            size_hint=(1, None),
            height=dp(60),
            color=(0.5, 0.5, 0.5, 1),
            halign="center",
            valign="middle",
        )
        self.campo_texto.bind(size=self._actualizar_text_size)
        self.add_widget(self.campo_texto)

        # Feedback: alto fijo (nunca cambia) para que no se recalcule el
        # layout de toda la pantalla cada vez que aparece el texto.
        self.label_feedback = Label(
            text="",
            font_size=sp(20),
            size_hint=(1, None),
            height=dp(36),
        )
        self.add_widget(self.label_feedback)

        # Botón único: alterna entre "Verificar" y "Siguiente"
        self.boton_accion = Button(
            text="Verificar",
            font_size=sp(22),
            size_hint=(1, None),
            height=dp(65),
        )
        self.boton_accion.bind(on_press=self.accion_boton)
        self.add_widget(self.boton_accion)

        self.add_widget(Widget(size_hint=(1, None), height=dp(10)))

        # Teclado personalizado
        self.add_widget(crear_teclado(self._on_tecla))

        self.nueva_pregunta()

    def _on_tecla(self, tecla):
        self.texto_actual = aplicar_tecla(self.texto_actual, tecla)
        self._actualizar_campo_texto()

    def _actualizar_campo_texto(self):
        if self.texto_actual:
            self.campo_texto.text = self.texto_actual
            self.campo_texto.color = (0.1, 0.1, 0.1, 1)
        else:
            self.campo_texto.text = PLACEHOLDER
            self.campo_texto.color = (0.5, 0.5, 0.5, 1)

    def _actualizar_text_size(self, instance, value):
        instance.text_size = (instance.width, instance.height)

    def nueva_pregunta(self, *args):
        verbo, tiempo, persona = elegir_combo_azar(self.verbos, self.tiempos_seleccionados)
        if verbo is None:
            # Ningún verbo tiene datos para los tiempos elegidos: se usa
            # cualquier tiempo disponible en vez de trabar el quiz.
            verbo, tiempo, persona = elegir_combo_azar(self.verbos, TIEMPOS_DISPONIBLES)

        if verbo is None:
            # Ni siquiera hay un verbo con la estructura nueva ("tiempos"):
            # datos viejos o corruptos. Se avisa en vez de romper la app.
            self.label_pregunta.text = (
                "No hay verbos con datos cargados.\n"
                "Revisá verbos.json / data.json."
            )
            self._set_feedback("")
            self.texto_actual = ""
            self._actualizar_campo_texto()
            self.modo = "verificar"
            self.boton_accion.text = "Verificar"
            return

        datos = self.verbos[verbo]["tiempos"][tiempo][persona]

        self.respuesta_correcta = datos["italiano"].lower()
        self.label_pregunta.text = f"¿Cómo se dice\n'{datos['espanol']}'?"
        self._set_feedback("")
        self.texto_actual = ""
        self._actualizar_campo_texto()
        self.modo = "verificar"
        self.boton_accion.text = "Verificar"

    def _set_feedback(self, texto, color=None):
        """Cambia el texto del feedback. El alto queda fijo siempre (ver
        __init__), para que no se recalcule el layout de la pantalla."""
        self.label_feedback.text = texto
        if color is not None:
            self.label_feedback.color = color

    def accion_boton(self, *args):
        if self.modo == "verificar":
            self._verificar_respuesta()
        else:
            self.nueva_pregunta()

    def _verificar_respuesta(self):
        respuesta = self.texto_actual.strip().lower()
        if not respuesta:
            return

        self.total += 1
        if respuesta == self.respuesta_correcta:
            self.puntaje += 1
            self._set_feedback("¡Correcto!", color=(0.1, 0.6, 0.1, 1))
        else:
            self._set_feedback(f"Incorrecto. Era: {self.respuesta_correcta}", color=(0.7, 0.1, 0.1, 1))

        self.label_puntaje.text = f"Puntaje: {self.puntaje}/{self.total}"
        self.modo = "siguiente"
        self.boton_accion.text = "Siguiente"


class PantallaSeleccion(Screen):
    """Pantalla para elegir, con checkboxes, qué verbos practicar."""

    def __init__(self, todos_verbos, al_confirmar, **kwargs):
        super().__init__(**kwargs)
        self.todos_verbos = todos_verbos
        self.al_confirmar = al_confirmar
        self.checks = {}
        self.checks_tiempos = {}

        self.layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(15))

        self.titulo = Label(
            text="Elegí los verbos a practicar",
            font_size=sp(24),
            size_hint=(1, None),
            height=dp(50),
            color=(0.1, 0.1, 0.4, 1),
        )
        self.layout.add_widget(self.titulo)

        self.lista = BoxLayout(orientation="vertical", spacing=dp(4), size_hint=(1, None))
        self.lista.bind(minimum_height=self.lista.setter("height"))

        self.scroll = ScrollView(size_hint=(1, 1))
        self.scroll.add_widget(self.lista)
        self.layout.add_widget(self.scroll)

        self.titulo_tiempos = Label(
            text="Elegí los tiempos",
            font_size=sp(24),
            size_hint=(1, None),
            height=dp(50),
            color=(0.1, 0.1, 0.4, 1),
        )
        self.layout.add_widget(self.titulo_tiempos)

        self.lista_tiempos = BoxLayout(
            orientation="vertical", spacing=dp(4), size_hint=(1, None)
        )
        self.lista_tiempos.bind(minimum_height=self.lista_tiempos.setter("height"))
        self.layout.add_widget(self.lista_tiempos)
        self._crear_checks_tiempos()

        self.boton_empezar = Button(
            text="Empezar",
            font_size=sp(22),
            size_hint=(1, None),
            height=dp(65),
        )
        self.boton_empezar.bind(on_press=self._confirmar)
        self.layout.add_widget(self.boton_empezar)

        self.add_widget(self.layout)

        self._reconstruir_lista(self.todos_verbos)

    def actualizar_lista(self, todos_verbos):
        """Se llama cuando llegan verbos nuevos desde GitHub, para refrescar los checkboxes."""
        self.todos_verbos = todos_verbos
        self._reconstruir_lista(todos_verbos)

    def _reconstruir_lista(self, todos_verbos):
        self.lista.clear_widgets()
        self.checks = {}

        for verbo in todos_verbos:
            fila = BoxLayout(orientation="horizontal", size_hint=(1, None), height=dp(55))

            chk = CheckBox(active=True, size_hint=(None, 1), width=dp(50))
            self.checks[verbo] = chk
            fila.add_widget(chk)

            traduccion = todos_verbos[verbo].get("traduccion", "")
            texto_fila = f"{verbo} ({traduccion})" if traduccion else verbo
            fila.add_widget(
                Label(
                    text=texto_fila,
                    font_size=sp(22),
                    color=(0.1, 0.1, 0.1, 1),
                    halign="left",
                    valign="middle",
                )
            )
            self.lista.add_widget(fila)

    def _crear_checks_tiempos(self):
        self.lista_tiempos.clear_widgets()
        self.checks_tiempos = {}

        for tiempo in TIEMPOS_DISPONIBLES:
            fila = BoxLayout(orientation="horizontal", size_hint=(1, None), height=dp(55))

            chk = CheckBox(active=True, size_hint=(None, 1), width=dp(50))
            self.checks_tiempos[tiempo] = chk
            fila.add_widget(chk)

            fila.add_widget(
                Label(
                    text=ETIQUETAS_TIEMPO[tiempo],
                    font_size=sp(22),
                    color=(0.1, 0.1, 0.1, 1),
                    halign="left",
                    valign="middle",
                )
            )
            self.lista_tiempos.add_widget(fila)

    def _confirmar(self, *args):
        seleccionados = [v for v, chk in self.checks.items() if chk.active]
        if not seleccionados:
            seleccionados = list(self.todos_verbos.keys())

        tiempos_seleccionados = [t for t, chk in self.checks_tiempos.items() if chk.active]
        if not tiempos_seleccionados:
            tiempos_seleccionados = list(TIEMPOS_DISPONIBLES)

        self.al_confirmar(seleccionados, tiempos_seleccionados)


class PantallaQuiz(Screen):
    """Pantalla con el botón de arriba, el estado de actualización, y el quiz debajo."""

    def __init__(self, todos_verbos, tiempos_seleccionados, ir_a_seleccion, ir_a_articoli, ir_a_frases, **kwargs):
        super().__init__(**kwargs)
        self.todos_verbos = todos_verbos

        self.layout_raiz = BoxLayout(orientation="vertical")

        self.layout_raiz.add_widget(
            crear_fila_botones_top(ir_a_articoli, ir_a_frases, ir_a_seleccion)
        )

        # Estado de la actualización (buscando / sin conexión / error)
        self.label_estado = Label(
            text="",
            font_size=sp(13),
            size_hint=(1, None),
            height=dp(30),
            color=(0.4, 0.4, 0.4, 1),
            halign="center",
            valign="middle",
        )
        self.label_estado.bind(size=self._actualizar_text_size_estado)
        self.layout_raiz.add_widget(self.label_estado)

        self.layout_raiz.add_widget(Widget(size_hint=(1, None), height=dp(25)))

        self.quiz = QuizVerbos(todos_verbos, tiempos_seleccionados)
        self.layout_raiz.add_widget(self.quiz)

        self.add_widget(self.layout_raiz)

    def _actualizar_text_size_estado(self, instance, value):
        instance.text_size = (instance.width, instance.height)

    def actualizar_seleccion(self, verbos_filtrados, tiempos_seleccionados):
        self.layout_raiz.remove_widget(self.quiz)
        self.quiz = QuizVerbos(verbos_filtrados, tiempos_seleccionados)
        self.layout_raiz.add_widget(self.quiz)


class PantallaEnBlanco(Screen):
    """Pantalla vacía, placeholder para funciones futuras (articoli, frases)."""

    def __init__(self, volver, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(15))

        boton_volver = Button(
            text="Volver",
            font_size=sp(18),
            size_hint=(1, None),
            height=dp(50),
        )
        boton_volver.bind(on_press=lambda *a: volver())
        layout.add_widget(boton_volver)

        layout.add_widget(Widget())

        self.add_widget(layout)


class PantallaFrases(Screen):
    """Pantalla para practicar frases sueltas: una IA (Gemini) genera una
    oración corta en español y corrige la traducción al italiano."""

    def __init__(self, ir_a_seleccion, ir_a_articoli, ir_a_frases, obtener_clave, clave_invalida, **kwargs):
        super().__init__(**kwargs)

        self.obtener_clave = obtener_clave
        self.clave_invalida = clave_invalida
        self.verbos = {}
        self.tiempos_seleccionados = []
        self.frase_es = ""
        self.italiano_referencia = ""
        self.texto_actual = ""
        self.modo = "verificar"

        layout = BoxLayout(orientation="vertical", padding=dp(14), spacing=dp(8))

        layout.add_widget(crear_fila_botones_top(ir_a_articoli, ir_a_frases, ir_a_seleccion))

        self.label_frase = Label(
            text="",
            font_size=sp(20),
            size_hint=(1, None),
            height=dp(130),
            color=(0.1, 0.1, 0.4, 1),
            halign="center",
            valign="middle",
        )
        self.label_frase.bind(size=self._actualizar_text_size)
        layout.add_widget(self.label_frase)

        self.campo_texto = CampoTexto(
            text=PLACEHOLDER,
            font_size=sp(22),
            size_hint=(1, None),
            height=dp(60),
            color=(0.5, 0.5, 0.5, 1),
            halign="center",
            valign="middle",
        )
        self.campo_texto.bind(size=self._actualizar_text_size)
        layout.add_widget(self.campo_texto)

        self.label_feedback = Label(
            text="",
            font_size=sp(20),
            size_hint=(1, None),
            height=dp(36),
        )
        layout.add_widget(self.label_feedback)

        self.boton_accion = Button(
            text="Verificar",
            font_size=sp(22),
            size_hint=(1, None),
            height=dp(65),
        )
        self.boton_accion.bind(on_press=self._accion_boton)
        layout.add_widget(self.boton_accion)

        layout.add_widget(Widget(size_hint=(1, None), height=dp(10)))
        layout.add_widget(crear_teclado(self._on_tecla))

        self.add_widget(layout)

    def _actualizar_text_size(self, instance, value):
        instance.text_size = (instance.width, instance.height)

    def _on_tecla(self, tecla):
        self.texto_actual = aplicar_tecla(self.texto_actual, tecla)
        self._actualizar_campo_texto()

    def _actualizar_campo_texto(self):
        if self.texto_actual:
            self.campo_texto.text = self.texto_actual
            self.campo_texto.color = (0.1, 0.1, 0.1, 1)
        else:
            self.campo_texto.text = PLACEHOLDER
            self.campo_texto.color = (0.5, 0.5, 0.5, 1)

    def _set_feedback(self, texto, color=None, font_size=None):
        self.label_feedback.text = texto
        if color is not None:
            self.label_feedback.color = color
        self.label_feedback.font_size = font_size if font_size is not None else sp(20)

    def iniciar(self, verbos, tiempos_seleccionados):
        """Se llama al confirmar la selección de verbos/tiempos para Frases."""
        self.verbos = verbos
        self.tiempos_seleccionados = tiempos_seleccionados
        self.nueva_frase()

    def nueva_frase(self, *args):
        self.label_frase.text = "Generando frase..."
        self._set_feedback("")
        self.texto_actual = ""
        self._actualizar_campo_texto()
        self.modo = "verificar"
        self.boton_accion.text = "Verificar"
        self.boton_accion.disabled = True
        threading.Thread(target=self._generar_frase_bg, daemon=True).start()

    def _generar_frase_bg(self):
        api_key = self.obtener_clave()
        if not api_key:
            Clock.schedule_once(lambda dt: self.clave_invalida())
            return

        verbo, tiempo, persona = elegir_combo_azar(self.verbos, self.tiempos_seleccionados)
        if verbo is None:
            verbo, tiempo, persona = elegir_combo_azar(self.verbos, TIEMPOS_DISPONIBLES)
        if verbo is None:
            Clock.schedule_once(
                lambda dt: self._mostrar_error_frase("No hay verbos con datos cargados.")
            )
            return

        traduccion = self.verbos[verbo].get("traduccion", verbo)
        try:
            frase_es, italiano = generar_frase(verbo, traduccion, tiempo, persona, api_key)
            Clock.schedule_once(lambda dt: self._frase_generada(frase_es, italiano))
        except ClaveInvalidaError:
            Clock.schedule_once(lambda dt: self.clave_invalida())
        except Exception as e:
            print("ERROR al generar frase:", repr(e))
            Clock.schedule_once(
                lambda dt: self._mostrar_error_frase("No se pudo generar la frase. Revisá tu conexión.")
            )

    def _frase_generada(self, frase_es, italiano):
        self.frase_es = frase_es
        self.italiano_referencia = italiano
        self.label_frase.text = f"Escribí en italiano:\n'{frase_es}'"
        self.boton_accion.disabled = False

    def _mostrar_error_frase(self, mensaje):
        self.label_frase.text = mensaje
        self.boton_accion.disabled = False

    def _accion_boton(self, *args):
        if self.modo == "verificar":
            self._verificar_respuesta()
        else:
            self.nueva_frase()

    def _verificar_respuesta(self):
        respuesta = self.texto_actual.strip()
        if not respuesta:
            return
        self.boton_accion.disabled = True
        self._set_feedback("Verificando...", color=(0.4, 0.4, 0.4, 1))
        threading.Thread(target=self._verificar_bg, args=(respuesta,), daemon=True).start()

    def _verificar_bg(self, respuesta):
        api_key = self.obtener_clave()
        if not api_key:
            Clock.schedule_once(lambda dt: self.clave_invalida())
            return

        try:
            correcto = verificar_frase(self.frase_es, self.italiano_referencia, respuesta, api_key)
            Clock.schedule_once(lambda dt: self._mostrar_resultado(correcto))
        except ClaveInvalidaError:
            Clock.schedule_once(lambda dt: self.clave_invalida())
        except Exception as e:
            print("ERROR al verificar frase:", repr(e))
            Clock.schedule_once(lambda dt: self._mostrar_error_verificacion())

    def _mostrar_resultado(self, correcto):
        if correcto:
            self._set_feedback("¡Correcto!", color=(0.1, 0.6, 0.1, 1))
        else:
            self._set_feedback(
                self.italiano_referencia, color=(0.7, 0.1, 0.1, 1), font_size=sp(15)
            )
        self.modo = "siguiente"
        self.boton_accion.text = "Siguiente"
        self.boton_accion.disabled = False

    def _mostrar_error_verificacion(self):
        self._set_feedback("No se pudo verificar. Probá de nuevo.", color=(0.7, 0.1, 0.1, 1))
        self.boton_accion.disabled = False


class PantallaClaveIA(Screen):
    """Pide la clave de la API de Gemini la primera vez (o si la guardada
    dejó de funcionar) y la guarda en el celular. Nunca queda en el código."""

    def __init__(self, on_guardar, **kwargs):
        super().__init__(**kwargs)
        self.on_guardar = on_guardar

        layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(15))

        titulo = Label(
            text="Necesitás una clave gratis de la IA (Gemini)",
            font_size=sp(20),
            size_hint=(1, None),
            height=dp(80),
            color=(0.1, 0.1, 0.4, 1),
            halign="center",
            valign="middle",
        )
        titulo.bind(size=lambda inst, val: setattr(inst, "text_size", (val[0], None)))
        layout.add_widget(titulo)

        instrucciones = Label(
            text=(
                f"1. Andá a [ref=url][u]{URL_GEMINI_API_KEY}[/u][/ref]\n"
                "2. Iniciá sesión con Google y creá una clave (gratis)\n"
                "3. Copiala y pegala acá abajo"
            ),
            markup=True,
            font_size=sp(15),
            size_hint=(1, None),
            height=dp(110),
            color=(0.3, 0.3, 0.3, 1),
            halign="center",
            valign="middle",
        )
        instrucciones.bind(size=lambda inst, val: setattr(inst, "text_size", (val[0], None)))
        instrucciones.bind(on_ref_press=lambda inst, ref: abrir_url(URL_GEMINI_API_KEY))
        layout.add_widget(instrucciones)

        self.input_clave = TextInput(
            hint_text="Pegá tu clave acá (empieza con AIza...)",
            font_size=sp(16),
            size_hint=(1, None),
            height=dp(60),
            multiline=False,
        )
        layout.add_widget(self.input_clave)

        self.label_error = Label(
            text="",
            font_size=sp(14),
            size_hint=(1, None),
            height=dp(30),
            color=(0.7, 0.1, 0.1, 1),
        )
        layout.add_widget(self.label_error)

        boton_guardar = Button(
            text="Guardar",
            font_size=sp(20),
            size_hint=(1, None),
            height=dp(60),
        )
        boton_guardar.bind(on_press=self._guardar)
        layout.add_widget(boton_guardar)

        layout.add_widget(Widget())

        self.add_widget(layout)

    def mostrar_error(self, mensaje):
        self.label_error.text = mensaje

    def _guardar(self, *args):
        clave = self.input_clave.text.strip()
        if not clave:
            self.label_error.text = "Pegá una clave antes de guardar."
            return
        self.label_error.text = ""
        self.input_clave.text = ""
        self.input_clave.focus = False
        self.on_guardar(clave)


class QuizVerbosApp(App):
    def build(self):
        try:
            return self._build_real()
        except Exception:
            return self._pantalla_de_error(traceback.format_exc())

    def _pantalla_de_error(self, texto_error):
        """Si algo falla al arrancar, mostrar el error en pantalla en vez de
        quedar con la pantalla en blanco (así se puede leer sin necesitar
        una compu conectada por cable para ver el logcat)."""
        contenedor = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(10))
        titulo = Label(
            text="La app tuvo un error al iniciar:",
            font_size=sp(20),
            size_hint=(1, None),
            height=dp(50),
            color=(0.7, 0.1, 0.1, 1),
        )
        contenedor.add_widget(titulo)

        label_error = Label(
            text=texto_error,
            font_size=sp(13),
            size_hint=(1, None),
            color=(0.1, 0.1, 0.1, 1),
            halign="left",
            valign="top",
        )
        label_error.bind(
            width=lambda inst, val: setattr(inst, "text_size", (val, None)),
            texture_size=lambda inst, val: setattr(inst, "height", val[1]),
        )

        scroll = ScrollView(size_hint=(1, 1))
        scroll.add_widget(label_error)
        contenedor.add_widget(scroll)

        return contenedor

    def _build_real(self):
        self.title = "Tukyliano"

        # Ruta de datos propia de la app (escribible en Android, a diferencia
        # de la carpeta donde vive el script, que es de solo lectura ahí)
        self.ruta_local = os.path.join(self.user_data_dir, "verbos_local.json")
        self.ruta_gemini_key = os.path.join(self.user_data_dir, "gemini_key.txt")
        self._asegurar_datos_locales()

        with open(self.ruta_local, "r", encoding="utf-8") as f:
            datos = json.load(f)

        self.version_actual = datos.get("version", 1)
        self.todos_verbos = datos.get("verbos", datos)

        self.sm = ScreenManager(transition=NoTransition())

        self.pantalla_quiz = PantallaQuiz(
            self.todos_verbos,
            list(TIEMPOS_DISPONIBLES),
            ir_a_seleccion=self._ir_a_seleccion,
            ir_a_articoli=self._ir_a_articoli,
            ir_a_frases=self._ir_a_frases,
        )
        self.pantalla_seleccion = PantallaSeleccion(
            self.todos_verbos,
            al_confirmar=self._confirmar_seleccion,
        )
        self.pantalla_seleccion_frases = PantallaSeleccion(
            self.todos_verbos,
            al_confirmar=self._confirmar_seleccion_frases,
        )
        self.pantalla_articoli = PantallaEnBlanco(volver=self._ir_a_quiz)
        self.pantalla_frases = PantallaFrases(
            ir_a_seleccion=self._ir_a_seleccion,
            ir_a_articoli=self._ir_a_articoli,
            ir_a_frases=self._ir_a_frases,
            obtener_clave=self._cargar_clave_gemini,
            clave_invalida=self._clave_gemini_invalida,
        )
        self.pantalla_clave_ia = PantallaClaveIA(on_guardar=self._guardar_clave_y_continuar)

        self.sm.add_widget(self.pantalla_quiz)
        self.sm.add_widget(self.pantalla_seleccion)
        self.sm.add_widget(self.pantalla_seleccion_frases)
        self.sm.add_widget(self.pantalla_articoli)
        self.sm.add_widget(self.pantalla_frases)
        self.sm.add_widget(self.pantalla_clave_ia)

        self.pantalla_quiz.name = "quiz"
        self.pantalla_seleccion.name = "seleccion"
        self.pantalla_seleccion_frases.name = "seleccion_frases"
        self.pantalla_articoli.name = "articoli"
        self.pantalla_frases.name = "frases"
        self.pantalla_clave_ia.name = "clave_ia"

        self.sm.current = "quiz"

        # Chequear actualización en un hilo aparte para no trabar el arranque
        self.pantalla_quiz.label_estado.text = "Buscando verbos nuevos..."
        threading.Thread(target=self._verificar_actualizacion, daemon=True).start()

        return self.sm

    def _asegurar_datos_locales(self):
        """La primera vez que corre la app, copia el JSON por defecto a la
        carpeta de datos propia de la app (ahí sí se puede sobreescribir)."""
        if not os.path.exists(self.ruta_local):
            shutil.copy(RUTA_JSON_DEFAULT, self.ruta_local)

    def _cargar_clave_gemini(self):
        """Devuelve la clave de Gemini guardada en el celular, o None si
        todavía no se cargó ninguna."""
        if os.path.exists(self.ruta_gemini_key):
            with open(self.ruta_gemini_key, "r", encoding="utf-8") as f:
                clave = f.read().strip()
                if clave:
                    return clave
        return None

    def _guardar_clave_gemini(self, clave):
        with open(self.ruta_gemini_key, "w", encoding="utf-8") as f:
            f.write(clave.strip())

    def _guardar_clave_y_continuar(self, clave):
        self._guardar_clave_gemini(clave)
        self.sm.current = "seleccion_frases"

    def _clave_gemini_invalida(self):
        """Se llama cuando Gemini rechaza la clave guardada (inválida o
        revocada): la borra y vuelve a pedirla."""
        if os.path.exists(self.ruta_gemini_key):
            os.remove(self.ruta_gemini_key)
        self.pantalla_clave_ia.mostrar_error(
            "La clave guardada ya no funciona (¿fue revocada?). Pegá una nueva."
        )
        self.sm.current = "clave_ia"

    def _verificar_actualizacion(self):
        print("Chequeando actualización en:", URL_REMOTO)
        try:
            r = requests.get(URL_REMOTO, timeout=8)
            print("Código de respuesta:", r.status_code)
            r.raise_for_status()
            datos_remotos = r.json()
            print("Conectado correctamente")

            version_remota = datos_remotos.get("version", 0)
            print("Versión remota:", version_remota, "| Versión local:", self.version_actual)

            if version_remota > self.version_actual:
                with open(self.ruta_local, "w", encoding="utf-8") as f:
                    json.dump(datos_remotos, f, ensure_ascii=False)
                Clock.schedule_once(lambda dt: self._aplicar_actualizacion(datos_remotos))
            else:
                Clock.schedule_once(lambda dt: self._mostrar_estado("Ya tenés la última versión."))
        except requests.exceptions.RequestException as e:
            print("ERROR al chequear actualización:", repr(e))
            mensaje = "Sin conexión a internet. Usando los verbos guardados."
            Clock.schedule_once(lambda dt: self._mostrar_estado(mensaje))
        except Exception as e:
            print("ERROR al chequear actualización:", repr(e))
            mensaje = "No se pudo comprobar si hay verbos nuevos."
            Clock.schedule_once(lambda dt: self._mostrar_estado(mensaje))

    def _aplicar_actualizacion(self, datos_remotos):
        try:
            self.todos_verbos = datos_remotos.get("verbos", {})
            self.version_actual = datos_remotos.get("version", self.version_actual)
            self.pantalla_seleccion.actualizar_lista(self.todos_verbos)
            self.pantalla_seleccion_frases.actualizar_lista(self.todos_verbos)
            self._mostrar_estado("")
        except Exception as e:
            print("ERROR al aplicar actualización:", repr(e))
            self._mostrar_estado(f"Error al aplicar actualización: {e}")

    def _mostrar_estado(self, texto):
        print("Estado:", texto)
        self.pantalla_quiz.label_estado.text = texto

    def _ir_a_seleccion(self):
        self.sm.current = "seleccion"

    def _ir_a_articoli(self):
        self.sm.current = "articoli"

    def _ir_a_frases(self):
        if self._cargar_clave_gemini():
            self.sm.current = "seleccion_frases"
        else:
            self.sm.current = "clave_ia"

    def _ir_a_quiz(self):
        self.sm.current = "quiz"

    def _confirmar_seleccion(self, verbos_seleccionados, tiempos_seleccionados):
        filtrados = {v: self.todos_verbos[v] for v in verbos_seleccionados}
        self.pantalla_quiz.actualizar_seleccion(filtrados, tiempos_seleccionados)
        self.sm.current = "quiz"

    def _confirmar_seleccion_frases(self, verbos_seleccionados, tiempos_seleccionados):
        filtrados = {v: self.todos_verbos[v] for v in verbos_seleccionados}
        self.pantalla_frases.iniciar(filtrados, tiempos_seleccionados)
        self.sm.current = "frases"


if __name__ == "__main__":
    QuizVerbosApp().run()
