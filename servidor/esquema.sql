-- Lo único que guarda el servidor.
--
-- Una fila por persona y por día, con cuántos mensajes lleva. Nada de lo que
-- se escribe en el chat pasa por acá: ni la charla, ni la respuesta, ni de qué
-- se habló. Si alguien se hiciera de esta base, lo que vería es "un celular
-- mandó 14 mensajes el martes".
--
-- 'quien' es el número que la app se inventa la primera vez que se abre, y el
-- renglón del total del servidor usa el nombre reservado '* todos *'.

CREATE TABLE IF NOT EXISTS mensajes (
  quien   TEXT NOT NULL,
  dia     TEXT NOT NULL,        -- 2026-10-24, en UTC
  cuantos INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (quien, dia)
);

-- Para poder borrar lo viejo de un saque: pasada una semana, los contadores de
-- días anteriores no le sirven a nadie.
CREATE INDEX IF NOT EXISTS mensajes_por_dia ON mensajes (dia);

-- Las palabras que alguien buscó y el diccionario de la app no tenía.
--
-- Esta es la parte que hace que preguntarle a la IA valga la pena: se le
-- pregunta UNA vez por palabra en toda la historia del servidor, y a partir de
-- ahí cualquiera que busque esa misma palabra la recibe de acá, sin IA, sin
-- cuota y sin espera. El segundo que busque "lumicino" ya la tiene.
--
-- 'palabra' viene normalizada igual que las claves del diccionario de la app:
-- minúsculas y sin tildes. Si no, "Lumicino" y "lumicino" serían dos filas y
-- dos preguntas a la IA por la misma palabra.
--
-- 'es' son las traducciones separadas por coma, como las muestra la app.
--
-- 'cuantas' sirve para decidir qué merece entrar al diccionario que viaja en
-- el APK: lo que se busca seguido conviene que esté adentro y no cueste ni
-- una ida al servidor.
CREATE TABLE IF NOT EXISTS palabras (
  palabra TEXT PRIMARY KEY,
  es      TEXT NOT NULL,
  base    TEXT,                 -- de qué palabra viene, si es una forma
  cuando  TEXT NOT NULL,        -- 2026-11-16, en UTC
  cuantas INTEGER NOT NULL DEFAULT 1
);

-- Para bajar de un saque las más buscadas y meterlas en el próximo APK.
CREATE INDEX IF NOT EXISTS palabras_por_uso ON palabras (cuantas DESC);
