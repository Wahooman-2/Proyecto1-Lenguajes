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

## D2. Que guarda el estado?

Redactó: Brian

**Contexto.** El juego tiene muchos estados distintos en los que puede estar un jugador, dependen de de donde te encuentres en
el mapa, que objetos tengas en tu inventario, cuantos turnos te queden, etc. El programa requiere una manera de llevar registro
de eso.

**Opciones.**
1. Una estructura de datos que solo registre que cosas se han modificado en el mundo.
2. Una estructura similar pero que lleve consigo una copia del mundo donde vayan haciendo las modificaciones en vivo
que realiza el jugador.

**Decisión.** Decidi irme por la opcion 2. Tenemos una estrucutra de datos `estado` que contiene una copia del mundo
en `firmaMundo` asi como otros campos para llevar registro de que hay en el inventario, cuantos turnos quedan, etc.

**Consecuencias.**
Gracias a esto las transiciones de un estado a otro son bastante intuitivas y pueden tomar ventaja de la programacion
fucional de Haskell. Ademas, mas adelante me permitio implementar las funciones de guardado y cargado de una manera
sencilla y elegante. Lo malo es que puede llegar a ser muy ineficiente para mundos grandes, la idea de crear copias
del mundo con pequeños cambios cada vez que se ejecuta un comando puede ser perturbadora para algunos, pero en todas
las pruebas que hice no se vieron problemas de desempeño.

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

## D5. Variante turnos

Redactó: Brian

**Contexto.** Nuestra version del motor de juegos requiere que tengamos una variable adicional `turnos` que defina un
limite de acciones que el jugador puede realizar antes de que se acabe su tiempo y acitve el estado de perder. Hay muchas
perspectivas con las que se puede implementar la funcionalidad de esta variable.

**Opciones.**
Existe una infinidad de posibilidades de como implementar esto, se podria restar un turno cada vez que se envia un comando,
nada mas los comandos que hacen que el jugador dentro del juego realize una accion, o incluso podrian haber acciones que
gasten mas turnos que otras.

**Decisión.** Originalmente quise simplemente restar un turno cada vez que se ejeutara un comando diegetico (acciones que hace
el personaje dentro del juego) pero a medida que hacia playtesting notaba que una de mis partes favoritas del juego
era leer las descripciones de objetos y habitaciones, y me frustraba el hecho de que realizar algo tan simple como mirar un
objeto o mirar tus alrededores restara un turno. Entonces decidi relajar las reglas un poco; solo agarrar objetos, soltar objetos
y moverse (y un comando especial secreto) gastan turnos. Me parece cruel castigar al jugador por curiosear.

**Consecuencias.**
Esta decision da mucha mas libertad al jugador de explorar y apreciar todo el texto adicional escrito por el desarrollador
del mundo sin sentir la presion de que querer leer estas descripciones lo pueda hacer perder el juego. Lo malo es que esto hace
el juego mucho mas facil, pero quien dijo que los juegos faciles son malos.

## D6. Formas de los comandos aceptados

Redactó: Brian

**Contexto.** Como es una aventura de texto, el jugador se debe poder comunicar con el programa utilizando algo que se aproxime
al lenguaje natural. Pero el lenguaje natural es demasiado flexible, con una infinidad de sinonimos y maneras distintas de
describir la misma accion, hay que delimitar que es considerado un comando valido y que no.

**Opciones.**
1. Ser completamente estrictos y solo aceptar lo definido por las especificaciones.
2. Tener un poco mas de flexibilidad respecto al uso de sinonimos, mayusculas, formato e incluso palabras de por medio.
3. Incluir un LLM que interprete cualquier mensaje y lo traduzca a comandos.

**Decisión.** Fui por la opcion 2 pero con unas pocas restricciones. Durante playtesting a veces me costaba recordar las
palabras definidas para cada accion, a veces recordaba un sinonimo en vez de la palabra real y realentizaba el progreso
del juego. Para que el jugador no se sienta tan presionado a memorizar los comandos tal cual, pues se supone que esta hablando
en lenguaje natural, inclui varios sinonimos para las palabras mas usadas del juego. Para `mirar` tenemos `ver` y `estado` (pues
la realidad es que estas revisando el estado de tu personaje), para `tomar` tenemos `coger` (obligatoria) y `agarrar` y `reoger`,
para `soltar` esta `botar`, para `examinar` hay `revisar` y para `ir` tenemos `caminar`, `entrar` asi como simplemente introducir
una de las 6 direcciones validas sin verbo previo (requisito de pruebas del profesor). Tambien, puse un filtro de articulos
como `a`, `el`, `la`, etc que permite al jugador introducir oraciones mas gramaticalmente correctas y que el comando siga siendo
valido. Era posible tambien aceptar espacios como substituto para `_` con los nombres de objetos pero eso parecia muy engorroso
de programar. Tambien hice que los comandos guardar y cargar se puedan ejecutar sin proporsionar un nombre, esto guarda/carga el
progreso con un archivo por defecto "guardado.txt", una vez mas, para aquellos que no saben mucho de computadoras.

**Consecuencias.**
Implementar todas estas comodidades le da al jugador mayor libertad de como formula sus comandos, es posible que jueguen personas
que no tengan idea de como funciona una computadora, entonces es bueno tomarlas en cuenta y hacerlas sentir que con cualquier
oracion que les venga a la mente pueden ser entendidos por la computadora. Lo malo es que el filtro de articulos tiene el 
efecto secundaro de tomar validos comandos sin sentido como leer `ir al la el a norte los un` como `ir norte` exitosamente. Pero
no considero que eso se mayor problema, la mayoria no lo van a descubrir, y los que si, probablemente saben que estan haciendo
y como funciona de transfondo. Mientras que no rompa el juego, por que no dejar que se diviertan.

## D7. Formato de las partidas guardadas

Redactó: Brian

**Contexto.** No se puede esperar que un jugador complete una partida en una sola sentada, se les puede ocurrir un mundo enorme
o la computadora se puede quedar sin bateria. Para estos casos es necesaria la capcidad de poder guardar y cargar partidas.

**Opciones.**
1. Guardar solo los cambios que han ocurrido con un show/read.
2. Guardar todo el estado de juego, tambien con un show/read.
3. Crear un archivo base con un formato especial desde el inicio e irlo editando cuando ocurran cambios.

**Decisión.** La opción 2. Esta fue una de las razones principales por las que decidi guardar el mundo completo con sus cambios
dentro de estado. Gracias a esto realizar un guardado eran tan simple como tomar ventaja de las derivaciones de Haskell y escribir
un show del estado en un archivo. Todos los cambios y el mundo completo se guardan con un solo comando, para cargar solo se tenia
que verificar que el titulo del mundo del guardado coincidiera con el del mundo actual.

**Consecuencias.**
La implementacion de los guardados es extremadamente facil tanto de escribir como de cargar y verificar. Sin embargo, tenemos el
mismo problema de eficiencia que con estado, estamos guardando el mundo completo, es posible que esto genere archivos mas pesados.
Pero es un riesgo que se puede asumir por comodidad. Un resultado interesante de esto es que se puede cargar una partida aunque
los mundos no coincidan, solo deben coincidir sus titulos. Esto lleva a la situacion curiosa de que un jugador puede editar el
archivo que describe su mundo e igual cargar una partida de una version desactualizada. Considero que esto no es del todo malo,
asi si un jugador esta haciendo playtesting y decide que quiere realizar un cambio pequeño en plena partida, no tiene que crear
un guardado nuevo por cada cambio que haga (a no ser que el cambio sea al nombre del mundo).

## D8. Cómo se lee la entrada y qué pasa al llegar al fin de la entrada

Redactó: Cristina

**Contexto.** El programa tiene que funcionar con la entrada redirigida desde un archivo (`aventura mundo.txt < guion.txt`) y terminar normalmente cuando la entrada se acaba, sin excepciones. En Haskell, `getLine` lanza una excepción de fin de archivo cuando ya no queda nada que leer. Además, la entrada estándar se puede leer de dos formas muy distintas, y una de ellas usa la evaluación perezosa, así que no era obvio cuál convenía.

**Opciones.**
1. `getContents` y procesar `lines` con una función que consume los comandos uno por uno. La lectura es perezosa: la lista de líneas se va construyendo a medida que llegan.
2. `getLine` dentro de un bucle recursivo, con `isEOF` para saber si queda algo antes de leer.
3. `getLine` y capturar la excepción de fin de archivo (no la vimos en clase, así que la descartamos).

**Decisión.** La opción 2. En `app/Main.hs`, `loopJuego` imprime el indicador, hace `hFlush stdout`, llama a `isEOF` y solo si queda entrada llama a `getLine`. Si no queda, imprime "Fin de la entrada. Saliendo..." y vuelve normalmente, así que el programa termina con código 0.

**Papel de la evaluación perezosa.**
- `readFile` es perezoso, pero `leerMundo` necesita todo el texto para decidir si hay errores. Por eso el archivo del mundo se lee completo (y se cierra) antes de que empiece el juego.
- Con `getContents` la entrada también sería perezosa y funcionaría de forma interactiva. Pero guardar y cargar partidas son acciones de IO en medio del bucle, y con lectura perezosa el orden entre leer, imprimir y escribir archivos depende de cuándo se fuerza cada parte. Con `getLine` e `isEOF` ese orden es explícito.

**Consecuencias.**
- Funciona igual con el teclado y con la entrada redirigida, y no lanza excepciones al llegar al fin.
- El indicador se imprime también antes de detectar el fin, así que con entrada redirigida la salida termina con un indicador y el mensaje de fin en la misma línea. Es solo un detalle de presentación.
- No tratamos el juego como una función pura de la lista de comandos. A cambio, el núcleo (`ejecutar`) sí es puro y se prueba aparte.
- Lo haríamos distinto separando la parte que interpreta una línea de la que lee, y agregando una prueba automática del programa completo con la entrada redirigida.

## D9. Si una salida bloqueada queda abierta para siempre después de cruzarla

Redactó: Cristina

**Contexto.** El enunciado define una salida bloqueada como la que declara `requiere <objeto>`: solo se puede cruzar si el jugador lleva ese objeto en el inventario. No dice qué pasa después de cruzarla: si queda abierta para siempre o si el requisito se vuelve a comprobar cada vez. Importa porque con `soltar` el jugador puede dejar el objeto en una sala y seguir caminando.

**Opciones.**
1. Comprobar el inventario cada vez que se intenta cruzar.
2. Guardar en el `Estado` un conjunto de salidas abiertas (sala y dirección) y no volver a pedir el objeto cuando ya se abrió.

**Decisión.** La opción 1. En `ejecutar` (`app/Motor/Nucleo.hs`), el caso `Ir` mira el campo requisito de la salida. Si hay un objeto requerido y no está en el inventario, responde "Necesitas ... para entrar aqui." y devuelve el mismo estado, así que el jugador no se mueve ni gasta turno. Si no hay requisito, o el objeto está en el inventario, lo mueve. No se guarda nada sobre las salidas que ya se cruzaron.

**Consecuencias.**
- El `Estado` no necesita un campo extra, así que guardar y cargar partidas no cambian. La regla es la misma del enunciado y se explica en una frase.
- El jugador puede quedar atrapado si cruza con el objeto, lo suelta y la salida de regreso también lo pide. En `mundos/mundo.txt` las salidas de regreso no piden nada, así que no pasa.
- Lo haríamos distinto con un conjunto de salidas abiertas en el `Estado` si quisiéramos puertas que se abren una sola vez, pero habría que guardarlo también en las partidas guardadas.

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
