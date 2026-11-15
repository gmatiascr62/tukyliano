# El servidor del chat

Un programa chico que vive en Cloudflare. La app le manda la charla y él le
pregunta a un modelo de **Workers AI**, que corre en la misma cuenta.

**No hay ninguna clave en ningún lado.** Ni en la app, ni en el repositorio,
ni como secreto: los modelos los corre Cloudflare y el permiso es el de la
cuenta donde vive este worker. Antes esto era un intermediario con Google para
que la clave no viajara en el celular; ahora directamente no hay clave que
pueda viajar.

**Cambiar de modelo es cambiar un renglón.** `MODELO`, en `wrangler.toml`. Se
publica el servidor y contesta otro modelo, al instante y para todos, sin
tocar la app y sin que nadie instale un APK nuevo.

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
| `TOPE_DEL_SERVIDOR` | La red de seguridad: si un día pasa algo raro, deja de pedirle al modelo en vez de seguir gastando neuronas |

Se cuenta **antes** de preguntarle al modelo, no después. Es a propósito: un
error que se reintenta solo es justo lo que puede vaciar una cuota. El precio
es que un día con muchas fallas gasta tope sin haber hablado.

La cuota de verdad es la de Cloudflare: 10.000 neuronas por día en el plan
gratis, de toda la cuenta, que se reinician a las 00:00 UTC. Cuánto come cada
respuesta depende del modelo: uno grande gasta bastante más que uno chico.

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
base y el modelo son de mentira en los tests.

Eso también quiere decir que mudar el servidor a otro lado —Cloud Run, por
ejemplo, cuando haya facturación— es cambiar `index.js` y nada más.

## Cómo se publica

Lo hace solo el workflow `servidor.yml` cuando se toca esta carpeta. Para que
funcione hace falta, una sola vez:

1. **Crear la base** y correrle el esquema. Se puede desde el panel de
   Cloudflare (D1 → Create, y después la pestaña Console con `esquema.sql`) o
   por línea de comandos:
   ```bash
   wrangler d1 create tukyliano
   wrangler d1 execute tukyliano --remote --file=esquema.sql
   ```
   El id que devuelve va en `wrangler.toml`. No es un secreto.
2. **Un token de Cloudflare** cargado como secreto del repositorio en GitHub,
   con nombre `CLOUDFLARE_API_TOKEN`. Necesita permisos de **Workers Scripts :
   Edit**, **D1 : Edit** y **Workers AI : Edit**. Ojo: D1 **no** viene en la
   plantilla "Edit Cloudflare Workers", hay que agregarlo a mano.
3. **La lista de códigos**, cuando haya a quién repartirle:
   ```bash
   wrangler secret put CODIGOS
   ```

## Lo que todavía no está

- La app todavía le habla directo a Google con la clave del alumno. Apuntarla
  acá es el paso siguiente, y recién ahí desaparece la pantalla que la pide.
- Nunca se lo probó contra un modelo de verdad. Los tests usan un Workers AI
  de mentira, así que lo que está probado es la lógica, no que el modelo
  conteste lo que esperamos ni que siga las instrucciones.
