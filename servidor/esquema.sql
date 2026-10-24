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
