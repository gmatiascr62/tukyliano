import json
import os
import shutil
import threading
import traceback
import random

import requests

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.checkbox import CheckBox
from kivy.uix.scrollview import ScrollView
from kivy.uix.screenmanager import ScreenManager, Screen, NoTransition
from kivy.core.window import Window
from kivy.metrics import dp, sp
from kivy.graphics import Color, Rectangle
from kivy.clock import Clock

Window.clearcolor = (0.95, 0.95, 0.95, 1)

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
        super().__init__(orientation="vertical", padding=dp(20), spacing=dp(10), **kwargs)

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
            height=dp(150),
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

        # Feedback (sin altura fija: no ocupa espacio cuando está vacío)
        self.label_feedback = Label(
            text="",
            font_size=sp(20),
            size_hint=(1, None),
            height=0,
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
        self.add_widget(self._crear_teclado())

        self.nueva_pregunta()

    def _crear_teclado(self):
        contenedor = BoxLayout(
            orientation="vertical",
            spacing=dp(6),
            size_hint=(1, None),
        )
        alto_tecla = dp(58)
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
                boton.bind(on_press=self._on_tecla)
                fila_layout.add_widget(boton)
            contenedor.add_widget(fila_layout)

        fila_espacio = BoxLayout(
            orientation="horizontal",
            size_hint=(1, None),
            height=alto_tecla,
        )
        boton_espacio = Button(text="espacio", font_size=sp(18))
        boton_espacio.bind(on_press=self._on_tecla)
        fila_espacio.add_widget(boton_espacio)
        contenedor.add_widget(fila_espacio)

        return contenedor

    def _on_tecla(self, instance):
        tecla = instance.text
        if tecla == "<--":
            self.texto_actual = self.texto_actual[:-1]
        elif tecla == "espacio":
            self.texto_actual += " "
        else:
            self.texto_actual += tecla
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

    def _elegir_combo(self, tiempos):
        """Elige verbo, tiempo y persona al azar, entre los que tengan datos
        cargados para alguno de los tiempos pedidos."""
        verbos_validos = [
            v for v, datos in self.verbos.items()
            if any(t in datos.get("tiempos", {}) for t in tiempos)
        ]
        if not verbos_validos:
            return None, None, None

        verbo = random.choice(verbos_validos)
        tiempos_verbo = [t for t in tiempos if t in self.verbos[verbo]["tiempos"]]
        tiempo = random.choice(tiempos_verbo)
        persona = random.choice(list(self.verbos[verbo]["tiempos"][tiempo].keys()))
        return verbo, tiempo, persona

    def nueva_pregunta(self, *args):
        verbo, tiempo, persona = self._elegir_combo(self.tiempos_seleccionados)
        if verbo is None:
            # Ningún verbo tiene datos para los tiempos elegidos: se usa
            # cualquier tiempo disponible en vez de trabar el quiz.
            verbo, tiempo, persona = self._elegir_combo(TIEMPOS_DISPONIBLES)

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
        etiqueta_tiempo = ETIQUETAS_TIEMPO.get(tiempo, tiempo)
        self.label_pregunta.text = f"¿Cómo se dice\n'{datos['espanol']}'\n({etiqueta_tiempo})?"
        self._set_feedback("")
        self.texto_actual = ""
        self._actualizar_campo_texto()
        self.modo = "verificar"
        self.boton_accion.text = "Verificar"

    def _set_feedback(self, texto, color=None):
        """Cambia el texto del feedback y su alto (0 si está vacío, para no
        dejar un hueco fijo cuando todavía no se verificó nada)."""
        self.label_feedback.text = texto
        self.label_feedback.height = dp(45) if texto else 0
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

    def __init__(self, todos_verbos, tiempos_seleccionados, version_actual, ir_a_seleccion, **kwargs):
        super().__init__(**kwargs)
        self.todos_verbos = todos_verbos
        self.ir_a_seleccion = ir_a_seleccion

        self.layout_raiz = BoxLayout(orientation="vertical")

        self.boton_top = Button(
            text=f"Seleccionar verbos (versión {version_actual})",
            font_size=sp(18),
            size_hint=(1, None),
            height=dp(50),
        )
        self.boton_top.bind(on_press=lambda *a: self.ir_a_seleccion())
        self.layout_raiz.add_widget(self.boton_top)

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

        self.layout_raiz.add_widget(Widget(size_hint=(1, None), height=dp(15)))

        self.quiz = QuizVerbos(todos_verbos, tiempos_seleccionados)
        self.layout_raiz.add_widget(self.quiz)

        self.add_widget(self.layout_raiz)

    def _actualizar_text_size_estado(self, instance, value):
        instance.text_size = (instance.width, instance.height)

    def actualizar_version_boton(self, version):
        self.boton_top.text = f"Seleccionar verbos (versión {version})"

    def actualizar_seleccion(self, verbos_filtrados, tiempos_seleccionados):
        self.layout_raiz.remove_widget(self.quiz)
        self.quiz = QuizVerbos(verbos_filtrados, tiempos_seleccionados)
        self.layout_raiz.add_widget(self.quiz)


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
        self._asegurar_datos_locales()

        with open(self.ruta_local, "r", encoding="utf-8") as f:
            datos = json.load(f)

        self.version_actual = datos.get("version", 1)
        self.todos_verbos = datos.get("verbos", datos)

        self.sm = ScreenManager(transition=NoTransition())

        self.pantalla_quiz = PantallaQuiz(
            self.todos_verbos,
            list(TIEMPOS_DISPONIBLES),
            self.version_actual,
            ir_a_seleccion=self._ir_a_seleccion,
        )
        self.pantalla_seleccion = PantallaSeleccion(
            self.todos_verbos,
            al_confirmar=self._confirmar_seleccion,
        )

        self.sm.add_widget(self.pantalla_quiz)
        self.sm.add_widget(self.pantalla_seleccion)

        self.pantalla_quiz.name = "quiz"
        self.pantalla_seleccion.name = "seleccion"

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
            self.pantalla_quiz.actualizar_version_boton(self.version_actual)
            self._mostrar_estado("")
        except Exception as e:
            print("ERROR al aplicar actualización:", repr(e))
            self._mostrar_estado(f"Error al aplicar actualización: {e}")

    def _mostrar_estado(self, texto):
        print("Estado:", texto)
        self.pantalla_quiz.label_estado.text = texto

    def _ir_a_seleccion(self):
        self.sm.current = "seleccion"

    def _confirmar_seleccion(self, verbos_seleccionados, tiempos_seleccionados):
        filtrados = {v: self.todos_verbos[v] for v in verbos_seleccionados}
        self.pantalla_quiz.actualizar_seleccion(filtrados, tiempos_seleccionados)
        self.sm.current = "quiz"


if __name__ == "__main__":
    QuizVerbosApp().run()
