# NGR: separar la presentación del módulo y de la biblioteca

Diagnóstico abierto, 2026-10-18. Checkout: `/Users/averrik/Cloud/github/libraries/NGR`. Criterio del propietario: README raíz dedicado al módulo, CLI y skill; README de biblioteca dedicado a su API y uso, sin repetir explicaciones. Auditoría documental local; no se ejecutaron operaciones ni se comprobó la publicación remota.

Superficies: `README.md` presenta componentes e instalación; `lib/README.md` contiene ejemplos y API R; `cli/README.md` desarrolla la interfaz de comandos; `skills/ngr/SKILL.md` contiene el procedimiento consumidor. `.github/workflows/pkgdown.yaml:31-41` construye desde `lib/` y publica `lib/docs`; la portada de esa construcción toma `lib/README.md`, no el README raíz. `lib/_pkgdown.yml:8-26` añade metadatos de portada y navegación al CLI.

## Hallazgos

- La raíz ya mantiene fuera los ejemplos de `buildPlot()` y `buildTable()` presentes en `lib/README.md:47-117`; no hay un catálogo de API duplicado. Sí se repiten explicaciones del módulo: raíz:18-24 y biblioteca:38-43 describen instalador común, acceso al checkout y que los comandos no instalan dependencias. La raíz:21 dice `Runtime commands load the installed package and do not install dependencies`; la biblioteca:42 dice `Runtime commands do not install dependencies`. Coinciden en esa explicación, aunque las frases no son idénticas. La biblioteca vuelve a explicar la distribución del módulo en vez de remitir a una entrada responsable de esa información.
- La tabla raíz:8-10 identifica CLI y skill, pero no explica sus tareas. El skill figura como `Producer prototype`, sin una descripción del flujo que orienta. Las operaciones están disponibles como fuentes de redacción: `cli/main.R:39-52` distingue `pull`, `status`, `doctor`, `render` y `deploy`; `skills/ngr/SKILL.md:8-11,39-45` distingue incorporación de recursos, render y publicación. El lector de la raíz conoce el estado de los componentes, pero debe salir de ella para saber qué hace el módulo.

## Reparto recomendado

La raíz debe resumir las operaciones del CLI, sus entradas de proyecto y el papel del skill, con enlaces a `cli/README.md` y `skills/ngr/SKILL.md`. La biblioteca conserva conceptos, ejemplos R, API y dependencias; la instalación conjunta y los destinos del CLI se explican en la superficie del módulo, con una remisión breve desde la biblioteca. Los enlaces a los artículos de CLI pueden permanecer como navegación, sin copiar sus instrucciones. La documentación detallada del CLI ya tiene ubicación propia; no necesita copiarse íntegra a la raíz.

## Prompt para una tarea posterior

```text
En /Users/averrik/Cloud/github/libraries/NGR, corrige la separación documental descrita en dev/bugs/BUG-README-LIMITES-MODULO-LIBRERIA-20261018.md. Lee el README raíz, lib/README.md, cli/README.md, skills/ngr/SKILL.md y los pasajes citados del CLI antes de redactar. Explica en la raíz incorporación y comparación de recursos, render y publicación como operaciones separadas, y qué aporta el skill consumidor; enlaza sus detalles. Retira de lib/README.md la explicación duplicada de instalación conjunta/runtime y conserva allí el uso y API R, con enlace al módulo. No traslades ejemplos R a la raíz ni copies el manual CLI entero. Conserva la diferencia entre prototipo de productor y skill aprobado/instalado. Verifica enlaces, destino de la portada y ausencia de explicaciones duplicadas. Entrega el diff documental; preserva trabajo ajeno y no cambies comportamiento, algoritmos, tests ni configuración, ni instales, ejecutes renders, publiques o hagas cambios de Git.
```
