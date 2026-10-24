# El servidor del chat

Un programa chico que vive en Cloudflare y hace de intermediario entre la app y
Gemini. La app le manda la charla, él le agrega la clave y se la pasa a Google,
y devuelve lo que contestó Tuky.

**Existe por una sola razón:** que la clave no viaje en ningún celular. Un APK
es un .zip; cualquiera que lo baje lo descomprime y lee lo que tenga adentro.
Acá la clave vive en un secreto de Cloudflare y no sale nunca.

## Qué expone

**`POST /charla`**

```json
{
  "quien": "el número que la app se inventó la primera vez",
  "codigo": "el de invitación, si hay lista",
  "saludo": "Ciao! Sono Tuky. Come stai?",
  "mensajes": [
    { "quien": "yo", "texto": "sto bene" }
  ]
}
```

Devuelve `{"texto": "..."}` o `{"error": "...", "mensaje": "..."}`. El `error`
es para el código y el `mensaje` es lo que se lee en pantalla, en criollo.

**`GET /salud`** → `{"ok": true}`. Para saber si está vivo sin gastar cuota.

## Qué guarda

Una fila por persona y por día con un número: cuántos mensajes lleva. Ver
`esquema.sql`.

**No guarda las charlas.** Ni lo que se escribe, ni lo que contesta, ni de qué
se habló. Si alguien se hiciera de la base, lo que vería es "un celular mandó
14 mensajes el martes".

## Los dos topes

| | Para qué |
|---|---|
| `TOPE_POR_PERSONA` | Repartir: que uno charlando toda la tarde no deje sin nada a los demás |
| `TOPE_DEL_SERVIDOR` | La red de seguridad: si un día pasa algo raro, deja de pedirle a Google en vez de seguir gastando |

Se cuenta **antes** de preguntarle a Google, no después. Es a propósito: un
error que se reintenta solo es justo lo que puede vaciar una cuota. El precio
es que un día con muchas fallas gasta tope sin haber hablado.

## ⚠️ La lista de códigos vacía deja la puerta abierta

Si `CODIGOS` está vacío, **entra cualquiera**. Está hecho así para poder probar
el servidor antes de tener a quién repartirle códigos.

Con el APK publicado en GitHub, dejarlo vacío significa que cualquiera que baje
la app gasta la cuota de Matías, sin que él sepa quién es ni pueda cortarlo.
Antes de repartir el APK hay que **o** cargar la lista de códigos **o** dejar
de publicarlo.

## Cómo se prueba

```bash
cd servidor && node --test 'test/*.test.js'
```

No hace falta cuenta de Cloudflare, ni internet, ni gastar cuota: `atender.js`
no nombra Cloudflare ni una vez y recibe todo lo de afuera por parámetro. La
base y Google son de mentira en los tests.

Eso también quiere decir que mudar el servidor a otro lado —Cloud Run, por
ejemplo, cuando haya facturación— es cambiar `index.js` y nada más.

## Cómo se publica

Lo hace solo el workflow `servidor.yml` cuando se toca esta carpeta. Para que
funcione hace falta, una sola vez:

1. **Crear la base** y pegar su id en `wrangler.toml`:
   ```bash
   wrangler d1 create tukyliano
   wrangler d1 execute tukyliano --remote --file=esquema.sql
   ```
2. **Cargar los secretos** en Cloudflare (nunca en el repo):
   ```bash
   wrangler secret put CLAVE_GEMINI
   wrangler secret put CODIGOS
   ```
3. **Un token de Cloudflare** cargado como secreto del repositorio en GitHub,
   con nombre `CLOUDFLARE_API_TOKEN`.

## Lo que todavía no está

- La app todavía le habla directo a Google: cambiarla es el paso siguiente.
- Nunca se lo probó contra Gemini de verdad. Los tests usan un Google de
  mentira, así que lo que está probado es la lógica, no que Google conteste lo
  que esperamos.
