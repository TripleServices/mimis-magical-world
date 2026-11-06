# Paquete Google Play — Mimi's Magical World (preparado 2026-11-01, actualizado 2026-11-05)

Estado (actualizado 2026-11-05, tarde): **¡CUENTA CREADA el 2026-11-05!** Desarrollador
«Guayo The Power», cuenta Personal, **ID 4986735702007689509**; el usuario pagó él mismo
los **$25** (recibo a edwardlawncare1@gmail.com). La preparación Android está hecha (JDK 17,
SDK, llaves de firmado, paquete `com.mimithekitty.magicalworld`, modo buy_only verificado en
`scripts/main.gd`: en Android no se ganan monedas jugando; Lulu sigue dando +40 s).
La cuenta vieja de josebatres133@gmail.com («My creations») fue CERRADA por Google el
18 may 2026 por inactividad; NO se pidió reactivación. **Corrección 2026-11-05:** la
«verificación en curso» del 1 nov NUNCA existió — los documentos de esa noche no dejaron
registro en ninguna cuenta; el registro se hizo desde cero el 5 nov y el nombre
«Guayothepower» ya estaba tomado por otro, por eso el nombre final es «Guayo The Power».
**Perfil de pagos:** quedó el existente a nombre de **Jose Mejia** (5240 Field Ln,
Winston-Salem, NC 27105) porque el documento del usuario dice Jose Mejia — Google no dejó
crear uno nuevo a nombre de Edward Mejia (un solo perfil personal por país). No cerrar ni
cambiar nada del perfil de Jose.
**AAB RECONSTRUIDO 2026-11-05 20:09:** `build/aab-work-v11/mimis-magical-world-signed.aab` (26.7 MB, v1.1 código 2, firmado con la llave de subida, verificado: universal APK con paquete correcto y GLB de Mimi Blender + teddy presentes). Script reutilizable: `build/aab-work-v11/rebuild-aab.sh`. **Capturas RETOMADAS 2026-11-05 20:14** del build actual con Mimi Blender (`play-store/screenshots/`: 01 casa, 02 escuela, 03 gimnasio, 04 playa, 05 tienda buy-only con texto correcto «Get coin packs to dress Mimi up!»; perfil de jugador nuevo, 0 monedas). Lección: el texto de la tienda se fija al construir el panel — en escritorio sale el de earn-mode; para la captura buy-only se pone a mano `shop_hint.text` en `tools/shot_play.gd`. El AAB viejo del 1 nov NO se sube.

## 1. Paquetes de monedas propuestos (decisión del usuario: solo comprar)

Precios de la tienda actual (fase 1): sombreros 30/60/90/200, cuello 40/80/120,
lentes 70/110. **Vestir a Mimi con TODO cuesta 800 monedas en total.**

| Paquete | Monedas | Precio sugerido | Qué alcanza |
|---|---|---|---|
| Starter | 100 | $0.99 | 1 sombrero o lentes básicos |
| Popular | 350 | $1.99 | Varias piezas |
| Full Wardrobe | 850 | $3.99 | Todo el guardarropa (800) + sobran 50 |

- Productos "consumibles" en Google Play Billing: se pueden volver a comprar.
- Google retiene ~15%; el resto se paga mensual al banco del desarrollador.
- La pantalla de compra va detrás de puerta para papás (requisito Familias).

## 2. Respuestas listas para la consola (copiar/pegar)

- **Data Safety:** No data collected · No data shared · Data is not encrypted in
  transit (no sale nada del dispositivo) · No account creation.
- **Target audience:** 5 and under / ages 3–6 (programa Designed for Families).
- **Ads:** No ads.
- **Privacy policy URL:** publicar `privacy-policy.md` de esta carpeta como página
  en GitHub Pages (gratis, como el sitio de Triple Services) y pegar esa URL.
- **Descripción corta (EN):** "Help Mimi find her lost toys! A gentle 3D adventure
  for little kids — explore the house, school and gym, dress Mimi up and play."
- Sin spoilers ni promesas falsas; el juego no recoge datos (verificable en el código).

## 3. Lo que falta, en orden (actualizado 2026-11-05, tarde)

1. ~~Cambiar `other_tcp` a Ask → AAB exportado y verificado.~~ HECHO (ruta manual).
2. **Usuario (2026-11-05, ~13:21 ET):** hará en casa esta noche los 4 pasos de
   verificación que pide la consola tras crear la cuenta: (1) verificar identidad
   subiendo su documento (el que dice **Jose Mejia**, que ya coincide con el perfil
   de pagos — no hay que cerrar ni cambiar nada); (2) declarar estado de operador;
   (3) verificar acceso a un Android entrando a la app móvil de Play Console;
   (4) verificar su número de teléfono (se completa con los otros). La verificación
   de identidad puede tardar varios días. **Ya NO aplica** lo del error OR_PMCR_47
   ni la espera del correo del 1–3 días hábiles: eso era de la ruta vieja, que no
   existía; el pago de $25 ya quedó hecho el 5 nov.
3. **Rio:** publicar la política de privacidad en GitHub Pages y dar la URL
   (la consola la pide al crear la app). LISTO PARA PUBLICAR: ya existe
   `privacy-policy.html` en esta carpeta (versión web de `privacy-policy.md`,
   preparada 2026-11-01); falta solo decidir en qué repo de GitHub Pages va y
   subirla — eso se hace cuando la cuenta de Play avance.
4. **Ficha de la tienda — assets:** ícono 512 YA existe (`assets/icon_512.png`).
   Imagen destacada 1024×500: BORRADOR PREPARADO 2026-11-01 en esta carpeta
   (`feature-graphic-1024x500.png`, desde la captura del jardín, Mimi al centro;
   espera aprobación del usuario). Capturas: las 7 de 1280×720 en
   `~/workspace/mimis-magical-world-shots/` son de una versión anterior
   (la portada dice «5 lost toys») — NO usar. **Auditoría 2026-11-01 (noche)
   de `tools/shots/` (build actual de 3 niveles):** SÍ sirven y ya están
   copiadas en `play-store/screenshots/`: escuela (`02-school-level2.png`,
   HUD correcto 0/8, 1:07) y gimnasio (`03-gym-level3.png`, 0/8, 1:21).
   NO sirven: jardín (`shot-garden.png` trae HUD de modo de prueba: 0/15 y
   temporizador 166:28) y tienda (`shot-shop.png` dice «Win levels and find
   Lulu to earn coins!», que contradice la versión de Play de solo compra).
   **Faltan 2 capturas limpias:** Nivel 1 Casa en modo normal (0/8, ~0:5x)
   y la tienda en modo Android buy-only. **OJO 2026-11-05:** las 2 capturas que sí
   hay (escuela y gimnasio, del 2 nov) muestran la Mimi procedural anterior — con la
   Mimi de Blender ya integrada conviene retomarlas del build actual antes de subirlas.
5. **Usuario decide:** precios finales de los 3 paquetes de monedas (tabla de arriba).
6. **Rio + usuario:** reconstruir el AAB desde el APK del 5 nov con la Mimi de Blender
   (ruta manual, NO usar el AAB del 1 nov), crear la app en la consola, subir el AAB,
   crear los productos, integrar Google Play Billing, prueba cerrada de 12 testers ×
   14 días (requisito de cuentas personales nuevas) y recién entonces publicación abierta.

## 4. Lo que NO cambia
- La versión web de itch.io sigue como demo en borrador, con monedas ganadas jugando.
- Nada de esto se publica sin el «sí» del usuario en cada paso con costo o publicación.
