<!--
decisiones de Cristina: D1, D3, D4 y D10.
-->

# Decisiones de diseño

## D1. Cómo se representan el mundo y los identificadores

Redactó: Cristina

**Contexto.** El mundo tiene salas, objetos y salidas que se refieren unas a otras por identificador. Había que decidir cómo guardar esas colecciones y cómo evitar confundir el id de una sala con el de un objeto. No era obvio porque el tipo puede garantizar algunas reglas del formato, pero no todas.

**Opciones.**
1. Listas de pares con `lookup` y los ids como `String` sin envolver.
2. `Map` para las salas, los objetos y las salidas, y un `newtype` para cada tipo de id.

**Decisión.** La opción 2. En `Motor.Tipos`, `IdSala` e `IdObjeto` son `newtype` sobre `String`. `Mundo` guarda `Map IdSala Sala` y `Map IdObjeto Objeto`, y cada `Sala` guarda sus salidas en un `Map Direccion Salida`.

**Consecuencias.**
- Ganamos que el compilador no deja pasar un `IdObjeto` donde va un `IdSala`, y que el tipo garantiza una sola salida por dirección en cada sala y un solo valor por id.
- El tipo no garantiza que el texto del id sea válido (eso lo comprueba `esIdentificador` al leer), ni que los destinos de las salidas existan, ni que `INICIO` exista. Eso lo comprueba `validar` en `Motor.Mundo`. Como `Mundo` se exporta con sus constructores, nada impide armar uno inválido a mano; en la práctica solo `leerMundo` lo construye.
- Un `Map` ya no deja ver los duplicados. Por eso `Motor.Mundo` primero lee `SalaCruda`, con las salidas en una lista, valida V2 y V5 sobre esas listas, y solo arma los `Map` en `construir`.

## D3. Cómo se reportan todos los errores y no solo el primero

Redactó: Cristina

**Contexto.** El enunciado pide que los errores de validación salgan todos juntos. Con `Either` y notación `do` no se logra: el `>>=` de `Either` deja pasar el `Left` sin llamar a lo que sigue, así que tras el primer error ya no se corre ninguna otra regla.

**Opciones.**
1. Encadenar las reglas con `do` en `Either ErrorMundo`.
2. Que cada regla devuelva su propia lista de errores y juntar las listas.
3. Un tipo propio con `Applicative` que acumule errores.

**Decisión.** La opción 2. En `validar` cada regla V2 a V10 es una lista por comprensión (`v2`, `v3`, ..., `v10`) y se juntan con `juntar`. En el reconocimiento, `reconocerCabecera`, `reconocerObjeto` y `reconocerSala` devuelven `Either [ErrorMundo]`, y `reconocer` junta los `Left` de todos los bloques. `leerMundo` solo llama a `validar` si `reconocer` no dio errores de sintaxis.

**Consecuencias.**
- Cada regla es una función aparte, fácil de leer y de probar, y los errores salen todos juntos.
- Un error de sintaxis (V1) oculta los de V2 a V10 hasta que se corrija.
- Para no encadenar errores: V7 y V10 solo cuentan objetos que sí están definidos (los que no ya salen en V4, V6 o V8), y V9 solo se revisa si `INICIO` existe.
- Se cuenta un error por cada violación. Esa convención puede no coincidir con la del profesor en casos como un objeto repetido en tres salas.
- Recorre las listas varias veces, pero los mundos son pequeños.
- Lo haríamos distinto con un tipo `Applicative` que acumule, si hubiera más reglas.

## D4. Cómo se diseñó el reconocedor

Redactó: Cristina

**Contexto.** Había que leer el formato `CLAVE: valor` sin librerías de parsing. Había que decidir la forma del reconocedor, qué hacer cuando da varias lecturas y cómo saber la línea de cada error.

**Opciones.**
1. Un `newtype Parser a` sobre `String -> [(a, String)]`, con instancias de `Functor`, `Applicative` y `Monad` y notación `do`.
2. Usar `ReadS` directamente, con listas por comprensión.

**Decisión.** La opción 2, en `Motor.Reconocedor`. Los combinadores son `caracter`, `literal`, `<|>`, `alternativas` (un `foldr`), `muchos`, `unoOMas`, `opcional`, `maximal`, `espacios`, `entero`, `identificador`, `restoDeLinea`, `fin` y `completo`.

- **Ambigüedad.** `muchos` y `unoOMas` devuelven todas las lecturas, la más larga primero. `maximal` se queda con la primera en las piezas que son una palabra (`espacios`, `entero`, `identificador`), para que un identificador no se parta. `completo` toma la primera lectura que consume toda la cadena.
- **Número de línea.** `preprocesar` numera las líneas antes de descartar comentarios y líneas vacías. El reconocedor se aplica a cada línea por separado con `completo lineaClave`, y el número viaja con la línea hasta que se arma el error.

**Consecuencias.**
- Se optó por esa opción porque es simple y cercana a lo visto en clase.
- `ReadS` devuelve la lista vacía al fallar, sin decir por qué, así que el mensaje lo decide quien llama. Para `SALIDA` se lee primero la forma con palabras (`salidaCruda`) y después se revisa cada palabra, para poder dar `DireccionInexistente` o `IdentificadorInvalido` en vez de un `SalidaMalFormada` genérico.
- `muchos` no termina si el reconocedor que recibe no consume nada; está anotado en el código.
- Lo haríamos distinto con un `newtype` y `do`: el código de `SALIDA` y `META` quedaría más corto.

## D10. Cómo se preprocesa el archivo y qué casos raros se aceptan

Redactó: Cristina

**Contexto.** El enunciado dice qué se ignora (líneas vacías, comentarios con `#`, espacios en los bordes) pero deja abiertos varios casos: archivos con fin de línea de Windows, la marca BOM de UTF-8, bloques vacíos y un `#` dentro de un texto. El profesor prueba con mundos que no conocemos.

**Opciones.**
1. Tratar `#` como comentario en cualquier parte de la línea, o solo cuando la línea empieza con `#`.
2. Recortar solo espacios, o también tabuladores, `\r` y BOM.
3. Dar error por un bloque vacío, o descartarlo.

**Decisión.** Solo son comentarios las líneas que empiezan con `#` (después de recortar). `recortar` quita espacios, tabuladores, `\r` y BOM. Los bloques vacíos se descartan. El separador es exactamente `---`. Las líneas se numeran antes de descartar nada.

**Consecuencias.**
- Un `DESC` que contiene `#` no se rompe, y un archivo hecho en Windows se lee bien.
- Un `---` de más al final o al principio no da error, pero tampoco se avisa de un separador duplicado por equivocación.
- Una línea como `----` no es separador y da un error de forma.
- Los errores apuntan a la línea real del archivo, aunque haya comentarios antes.
