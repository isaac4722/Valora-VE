# HALLAZGOS — v1.1.0-dp4-paridad · v33 «Revisión Goldfish de textos y documentación»

Ciclo ordenado por el dueño: «busca cualquier error o mala escritura y
arréglalo; verifica que todo esté completo; deja solo main y la rama dp4».
EGM operativo (skills egm-* del repo): **5 revisores Goldfish SIN CONTEXTO**
(docs públicos, bitácoras, CHANGELOG completo, strings de UI, contrato y
verdad funcional) auditando en paralelo; el elefante verificó cada hallazgo
contra el código y ejecutó las correcciones. Entorno: Flutter 3.47.4 (la
misma versión del CI), suite como gate en cada paso.

## Fase 0 — Entorno y herramientas

- EGM (Elephant-Goldfish Model, egm.dev): protocolo aplicado con las skills
  `egm-review`/`egm-draft`/`egm-lite`/`egm-drift-report` ya presentes en
  `.agents/skills/`; aislamiento real vía subagentes sin contexto.
- Skills de Fase 2 verificadas e instaladas: `flutter-unslop`,
  `anti-slop-design`, `unbland` (directorios + `SKILL.md` + entrada en
  `skills-lock.json`; instaladas en 78b8f6a). REA quedó como CLI/MCP del
  entorno del dueño (usada en ciclos previos contra el APK de CalculaYa);
  en este sandbox no aplica porque no hay APK que auditar.

## Textos de la UI (T) — todo CORREGIDO y verificado por la suite

- **T-1 · Concordancia «válido»** (4 strings): «Nombre y precio válido» /
  «Escribe nombre y precio válido» en `lista_screen` (×3) y `item_editor`.
  → «válidos».
- **T-2 · «Zona peligro»** (`settings_system`): aposición agramatical; el
  propio CHANGELOG v32 escribe «zona de peligro». → «Zona de peligro»
  (rótulo y comentario; MVP-CRUD alineado).
- **T-3 · Banner de salud** (`ui.dart`): «no se actualizan hace más de
  15 min» faltaba el «desde». → «desde hace más de 15 min».
- **T-4 · Semilla del catálogo** (`models.dart`): «Antiacídico pastillas»
  no existe en español. → «Antiácido en pastillas» (el test de semillas
  cuenta 21, no ancla nombres).
- **T-5 · Alta de tasas propias** (`settings_sections`): «Zelle, Efectivo,
  Binance… Aparece en Tasas con su brecha» — sujeto plural, verbo singular.
  → «Aparecen en Tasas con sus brechas».
- **T-6 · Toast de importación** (`products_screen` ×2): «Ya están en
  libro» → «Ya están en el libro».
- **T-7 · CSV de productos sin tildes** (T-7): encabezados «Codigo» /
  «Categoria» → «Código» / «Categoría», y el importador ahora acepta AMBAS
  grafías (`findCol(['codigo', 'código'])`): los CSV viejos sin tilde
  siguen importando, los nuevos también (round-trip intacto). Toast y
  doc-comment del ejemplo actualizados.
- **T-8 · CSV de brecha** (`insights_utils`): encabezado «Dia» → «Día»;
  los 2 expects de `insights_utils_test` actualizados en el mismo commit.
- **T-9 · Ortografía de comentarios de código**: «Calculaya» → «CalculaYa»
  en comentarios de `board.dart` (7 líneas; los identificadores
  `parseCalculayaTasas`/`_calculayaMemo` NO se tocan).

## Documentación (D) — todo CORREGIDO

- **D-1 · README desactualizado en 6 puntos** (contradecía a GUIA,
  CHANGELOG v31/v32 y al código): decía «+ AAB» en descarga y releases (el
  AAB se retiró en v31), enlazaba «Release v1.0.2-beta» cuando la última
  publicada es v1.0.3-beta (y el enlace apuntaba a /latest), «tres
  transportes» de Sala (son CUATRO: falta Bluetooth clásico RFCOMM/SPP),
  módulo «Más» con buscador y 8 destinos (v30: sin buscador, 5 destinos),
  Ajustes «hub con General…» (v32: una pantalla por secciones), y «fichas
  1-100» en el Conversor (retiradas en v29). También «El repo ya no
  arrastra documentación de proceso» era falso (AGENT/MVP-CRUD/PROGRESS/
  HALLAZGOS viven en el repo) y «# 3 APK por ABI» se leía «3 por cada ABI».
- **D-2 · MVP-CRUD §4 no reflejaba la orden del dueño de v31**: seguía
  «4 APK + AAB + ZIP … prohibido retirar el AAB». → política v31: solo APK
  (1 universal + 3 ABI) + ZIP, AAB retirado por orden del dueño. §4.10
  «tres transportes» → cuatro (Bluetooth clásico).
- **D-3 · MVP-CRUD §9 desactualizado**: Shell «7 rutas / ticker
  solo-inicio» (son 8 rutas; RateTicker retirado de Inicio en v26, vive en
  el pie del sidebar); Análisis «6 anclas» (v30: barra segmentada de 4
  secciones); Ajustes «8 anclas» (v32: UNA pantalla, 9 encabezados, cero
  subpantallas); Conversor «fichas 1-100 en el piso» y «Hoy/Ayer/7
  días/Fecha» (v29: fichas fuera, Fuentes/Tabla/Recientes fuera y Notas
  inline, fecha Ayer·Hoy·Mañana·Fecha); referencias huérfanas §9.6/§9.7
  eliminadas.
- **D-4 · MVP-CRUD §2/§8**: «13 claves AppData» (son 15 desde v23:
  +customRates +accounts, como el propio documento documenta);
  `lib/core/shad_theme.dart` citado como canónico en §8 (el archivo NO
  existe; canónicos reales `theme.dart` + `ui.dart`); RateTicker listado
  como componente firma (retirado en v26); «Calculaya» → «CalculaYa» (§3/§5).
- **D-5 · AGENT.md**: «59 skills» (son 67 directorios con SKILL.md);
  `shad_theme.dart` en la tabla de referencia canónica (inexistente);
  «lo registra… instalarlo» (skill es femenino en todo el contrato) → «la
  registra… instalarla»; «re-ejecuta» → «reejecuta»; touch targets ≥48dp
  aclarado como referencia de Material (el estándar del producto es 44,
  MVP-CRUD §9) para resolver la contradicción con §9.
- **D-6 · .agents/skills/README.md**: referenciaba `WORKFLOW.md` (no
  existe; el flujo vive en AGENT.md), citaba `docs/` (carpeta retirada en
  la consolidación) y «regístralo» → «regístrala»; el «catálogo» prometido
  no existía → la procedencia vive en `skills-lock.json` (ahora dice la
  verdad).
- **D-7 · GUIA_DE_LA_APP.md**: «sin servidores» tensionaba con el modo
  Servidor autoalojado → «sin nube»; «antes que romper la línea» → «antes
  de romper»; «escala única Redondeo/Precisión/Completo» → la real:
  «precisión 2/3/4/«Completo»» (H-26; Redondear es el toggle numMode).
- **D-8 · LICENSE**: «PROHIBICIONES EXPRESSAS» (portugués) → «EXPRESAS»;
  «incluido su código fuente, diseños…» → «incluidos».
- **D-9 · CHANGELOG.md** (8 fixes): «refactor completa» → «completo»;
  «el alta lo pide» → «la pide»; «sobreescribe» → «sobrescribe»;
  «APROBADO directo» → «APROBADOS»; «El cache del sistema» → «El caché»;
  «transividad» → «transitividad»; «deslazo» → «desplazamiento»; «keys
  compuestos» → «compuestas»; «dio baja el APK» → «baja el APK»;
  `REQUEST_INSTALL_PACKAGES` y `landscapeLeft/Right` partidos por salto de
  línea; «re-implementaron»/«re-tamañarse» → «reimplementaron»/
  «redimensionarse»; 6 «Calculaya» → «CalculaYa».
- **D-10 · HALLAZGOS v28/v31/v32**: «EG M operativo» → «EGM»; «el sub
  ENVUELVE a varias líneas» → «se envuelve en varias líneas»; «(7 puntos)»
  con 6 ítems listados → «6 puntos»; «display 17» → «title 17» (la escala
  del propio H-2); «380 lógico» → «380 px lógicos»; «Ningún binario del
  canal es no instalable» → «Todos los binarios del canal son
  instalables»; «teclado única vía, ⌫ largo limpia» → «teclado como única
  vía; …»; prefijos con guion («re-implementación», «Re-verificación»,
  «pre-existentes» ×3) → soldados (norma RAE).
- **D-11 · quality_gate.sh**: el comentario citaba «R5 del AGENT.md» y
  `docs/agent/TESTING.md` (ninguno existe) → cita el contrato real
  (Límites de Tres Niveles).
- **D-12 · PROGRESS/PROGRESS_WARM (ortografía de entradas previas)**:
  «mal configurado» → «mal configurados»; «redondeo SOLO la vista» → «SOLO
  en la vista»; «APROBADO» → «APROBADOS»; «dio baja el APK» → «baja el
  APK»; «actualizador canal dev» → «actualizador del canal dev»;
  «re-dirigidas»/«re-verificada» → soldadas; «Calculaya» → «CalculaYa»
  (×3). Solo ortografía: cifras y hashes históricos intactos.

## Completitud (C) — el «verifica que todo esté completo»

- **C-1 · Bitácora detenida en v28** (mayor): PROGRESS.md no tenía
  entrada de v25 ni de v29–v32 aunque el trabajo existe en git
  (29a5ac7, c854e54, 59cdfaf, 8f92a75, f342d96) y en los HALLAZGOS.
  → AÑADIDAS las 5 líneas (v25, v29+v30 recuperados, v31, v32, v33) con
  sus gates reales.
- **C-2 · TASK-35 abierta desde 2026-10-02**: su alcance (notch/SafeArea,
  techos, Sala, toggle de tema) quedó absorbido por v23–v32 y su parte de
  docs está cerrada en WARM/COLD desde octubre. → cerrada DONE con nota
  «cierre tardío registrado en v33» (desviación del «solo añadir» por
  orden del dueño, documentada aquí).
- **C-3 · Rotación nunca ejecutada + BUG en el script**: hot tenía 26
  entradas (contrato: ≤10) y CHANGELOG hot 22 versiones (contrato: 3).
  Al probar `tools/rotar_bitacora.sh --prueba` (como manda el contrato)
  se descubrió que `rotar_changelog` estaba ROTO: insertaba los bloques
  entrantes DESPUÉS del primer encabezado de WARM (partía la entrada v21.1
  de su cuerpo) y al superar 10 movía a COLD los bloques del PRINCIPIO
  (los MÁS NUEVOS, en un archivo newest-first). — **CORREGIDO** el script
  (los entrantes van arriba del todo; a COLD bajan los ÚLTIMOS, los más
  viejos, por arriba de su lista) y verificado en `--prueba` antes del
  uso real. Además, el hot histórico tenía orden mixto (bloque superior
  newest-first, inferior ascendente), lo que llevó las entradas más nuevas
  a COLD en la primera pasada; frontera WARM/COLD reparada a orden
  cronológico canónico (WARM = v26…v33 ascendente; COLD = el resto, 116
  entradas verificadas sin pérdida).
- **C-4 · Referencias a HALLAZGOS_v29/v30**: citados por CHANGELOG v31
  pero perdidos con el sandbox de aquel ciclo. → la cita del CHANGELOG
  re-apuntada a `HALLAZGOS_v31.md` (donde vive la especificación
  reconstruida); las menciones dentro de HALLAZGOS_v31 se conservan como
  registro histórico.
- **C-5 · Versión de ronda**: pubspec 1.18.0-beta+55 → **+56** y
  `kAppVersionVisible` 32 → **33** (el test de Actualizaciones quedó
  anclado a la constante en f342d96, así que el bump no rompe nada).

## Dudosos o no corregidos (registro honesto)

- CHANGELOG v23.3: «24 ocurrencias — 20 OK, 3 sospechosas, 0 fugas» suma
  23; PROGRESS repite «24». No hay forma de reconstruir el inventario
  original; se deja como está.
- CHANGELOG v27: «gate visual 9 capturas» enumera 8 pantallas. Probable
  captura doble (claro/oscuro) no identificable hoy.
- CHANGELOG v23.0: «seis grupos» con 5 nombres — «Datos y acerca de»
  puede leerse como dos grupos (6). Legítimo; se deja.
- «las 7 hojas que quedaban crudas» con «export×2» en la lista: si export
  cuenta doble son 8. Ambiguo; se deja en MVP-CRUD y CHANGELOG.
- PROGRESS v23.2b «43/43» (suite parcial sin etiqueta) y v23.2d «3
  commits» vs «4 parches 0002-0005» con hashes originales perdidos con el
  sandbox: entradas históricas, no se reescriben.
- HALLAZGOS_v28: 68 infos (L131) vs 69 infos (L182) de deprecación sin
  explicación del salto; HALLAZGOS_v32 G-1: ~20 px calculados vs ~35 px
  medidos (el resto: spacing de la barra de tabs).
- `scripts/sweep_ellipsis.py` citado por HALLAZGOS_v28 no está en el repo
  (herramienta efímera del sandbox de aquel ciclo; el barrido está
  verificado por tests de «0 ellipsis»).
- `taste-skill`, `taste-skill-v1` y `gpt-tasteskill` coexisten (regla de
  consolidación de duplicados): decisión de diseño pendiente del dueño.
- PROGRESS_COLD: la sección «## Hito 2026-11 · rotación automática»
  contiene solo entradas del 2026-10-02 (el encabezado lo genera el script
  con el mes de la rotación); inocuo.
- GUIA L5: «La versión con formato (Word/PDF) se entrega junto a cada
  ciclo» — entregable externo, no rastreado en el repo.

## Verificación

- `flutter analyze` (SDK 3.47.4): **0 issues**.
- Suite completa: **380/380 verdes** (base y post-cambios idénticas; los
  2 expects de insights actualizados en par con el código).
- `quality_gate.sh`: analyze + suite + auditoría de prohibiciones en
  `lib/` — VERDE.
- Versión: 1.18.0-beta+56 · visible 33 · CHANGELOG con entrada v33 y
  rotación ejecutada.
- **Push a origin BLOQUEADO desde este sandbox**: sin credenciales (el PAT
  del chat NO se usó, por política de seguridad — precedente v23.2d: un
  PAT pegado en chat se considera expuesto y no debe viajar por comandos).
  El ciclo completo viaja como **parches + bundle** en `download/` para
  aplicar y empujar desde la máquina del dueño:
  `git am *.patch` (o `git pull valorave-v33.bundle`) y `git push`.
  El CI re-verificará analyze + suite + auditoría al llegar.

## Ramas (orden del dueño: dejar solo main y la dp4)

El GitHub MCP de este entorno no expone borrado de ramas, así que quedan
anotadas para el dueño (1 comando cada una):

    git push origin --delete feat/gui-simple-egm
    git push origin --delete fix/converter-unescape
    git push origin --delete new-docs
    git push origin --delete safe/v1.1.0-dp4-paridad

Se conservan: `main` y `v1.1.0-dp4-paridad` (la dp4).

Verificación de contenido único (rev-list contra ambas ramas a conservar):

- `feat/gui-simple-egm`: **0** commits únicos (todo alcanzable desde
  main). Borrado sin pérdida.
- `fix/converter-unescape`: **0** commits únicos (todo alcanzable desde
  la dp4; es la punta v22.4 antigua). Borrado sin pérdida.
- `safe/v1.1.0-dp4-paridad`: **0** commits únicos (todo alcanzable desde
  la dp4). Borrado sin pérdida.
- `new-docs`: **2** commits que no viven en main ni en la dp4 — `0adc35c`
  (AGENT.md/LICENSE de la era v1.9.x) y `c946ed8` (CHANGELOG_WARM de
  v1.9.10-beta+28). Ambos quedaron obsoletos por la consolidación
  documental del 2026-10-02 (los archivos actuales los reemplazaron con
  contenido nuevo), así que el borrado es razonable; si se quiere
  conservar el histórico, fusionar esos SHAs a un tag de archivo antes de
  borrar (p. ej. `git tag archivo/new-docs origin/new-docs`).
