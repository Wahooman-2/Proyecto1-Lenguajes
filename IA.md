# Declaración de uso de IA

## Herramientas utilizadas

Para el desarrollo de mi parte del proyecto utilicé dos herramientas de inteligencia artificial:
* **Claude (Anthropic - modelo Claude Sonnet 5.5)** a través de su interfaz web (`claude.ai`), utilizada principalmente como herramienta de consulta técnica, resolución de bloqueos durante la implementación, depuración y apoyo en la generación de pruebas y borradores.
* **Gemini (Google)**, utilizado para la revisión, estructuración y redacción final de este documento de declaración (`IA.md`) (Cristina), asi como para la sugerencia de ideas respecto a implementacion y correccion de logica del codigo (Brian).

## Desglose del uso de IA en el proyecto

El apoyo de la IA se centró en aclarar dudas sobre características del lenguaje no vistas en clase, destrabar errores de compilación o lógica, y agilizar tareas de documentación y pruebas. A continuación se detalla cada aspecto agrupado por área:

### 1. Planificación y organización
1. **Organización del trabajo en pareja:** Se utilizó Claude para analizar los requerimientos del proyecto y obtener una propuesta inicial de cómo segmentar los módulos y repartir las tareas entre los integrante del equipo. La división final y la asignación definitiva las decidimos nosotros.

### 2. Consultas sobre Haskell y herramientas
2. **Estructuras de datos (`Data.Map`):** Al diseñar `Tipos.hs` y `Mundo.hs`, se consultó a Claude sobre alternativas más eficientes que las listas de pares con `lookup` vistas en clase. Claude presentó la opción de usar `Data.Map`, y se decidió implementarlo para los campos de `Sala`, `Mundo` y `Estado`, así como en las funciones `buscarSala`, `buscarObjeto` y `salidaEn` (usando `Map.lookup`), `construir` (usando `Map.fromList`) y `length` aplicado a un `Map` en las pruebas.
3. **Importaciones calificadas (`import qualified ... as`):** A raíz de la consulta anterior, Claude sugirió a utilizar `import qualified Data.Map as Map` para evitar conflictos de nombres con las funciones estándar del `Prelude`.
4. **Exportación de constructores con `(..)`:** Se consultó cómo exponer los constructores de los tipos de datos definidos en `Tipos.hs` hacia otros módulos mediante la sintaxis `Tipo(..)`.
5. **Derivación automática de `Read` (`deriving Read`):** Para el parseo de datos, se consultó cómo evitar escribir instancias manuales de `Read` y se utilizó `deriving Read` en los tipos `IdSala`, `IdObjeto`, `Direccion` y `Fin`.
6. **Secuencias de escape y manejo de caracteres especiales:** Al trabajar en la lectura y validación de archivos en `Mundo.hs` y en las pruebas, se consultó cómo representar y limpiar caracteres especiales de formato como la marca BOM de UTF-8 (`'\xFEFF'`), retornos de carro (`\r`) y tabulaciones (`\t`).
7. **Configuración del archivo `.cabal` (`test-suite`):** Se consultó a Claude cómo configurar la sección `test-suite` para poder ejecutar las pruebas unitarias correctamente.

### 3. Implementación, revisión y depuración
8. **Revisión de funciones con *pattern matching*:** en algunas de las funciones en las que se usó *pattern matching* se recurrió a Claude para validar que los casos estuvieran bien cubiertos y no faltaran patrones. 
9. **Depuración y resolución de bloqueos:** Ante el estancamiento con errores de tipos o fallos en tiempo de ejecución, se utilizó Claude para interpretar los mensajes del compilador (GHC) y entender el origen de los fallos. 
10. **Comentarios y formato del código:** Una vez que el código funcionaba, se le pedió a Claude que revisara el estilo, mejorara el formato de los archivos y añadiera comentarios descriptivos para mejorar la legibilidad, manteniendo intacta la lógica que ya se había implementado.

### 4. Pruebas y documentación
11. **Pruebas unitarias (`hspec`) y archivos de prueba (`.txt`):** Claude redactó la suite de pruebas en `test/PruebasMundo.hs` (utilizando `Test.Hspec` con `describe`, `it`, `shouldBe`, `shouldSatisfy` y `runIO`). Asimismo, Claude generó los archivos de texto de prueba: el mapa propio (`mundos/mundo.txt`), los casos de mundos inválidos (`mundos/invalidos/*.txt`) y el guion de comandos (`guiones/mundo.txt`).
12. **Redacción del `README.md`:** Claude me ayudó a estructurar y redactar la documentación general del proyecto en el archivo `README.md`.
13. **Redacción de `DECISIONES.md`:** Claude mejoró la redacción del archivo y lo pasó a formato .md
14. **Redacción de `IA.md` (este documento):** Se utilizó Gemini para organizar, categorizar y redactar de forma clara los puntos de esta declaración a partir de los apuntes sobre el uso de las herramientas.

## Ejemplos de sugerencias de Claude que se corrigieron o se rechazaron

- Claude sugirió usar `Enum`, `Bounded` y `[minBound .. maxBound]`, y `esIdentificador` usaba `all`. Cristina optó por algo mas simple ya visto en clase por lo que se Se reemplazó por una lista escrita a mano y por `filter`, `null` y composición (Cristina).
- La primera versión de los comentarios usaba el formato de documentación de Haddock (`-- |`, `-- ^`) y líneas separadoras. Cristina optó por comentarios simples, y se reescribieron (Cristina).
- Varias veces Gemini me insistio ir redactando el document de decisiones con cada implementacion que se hacia, yo decidi terminar todo el codigo primero y despues redactar todos los txts (Brian).
- Hubo un momento en el que estabamos discutiendo como decorar la interfaz para que muestre los turnos y cosas por el estilo, en algun momento surgio el tema de hacer que el `>` parpadee, se veia genial pero complicaba el codigo y era posible que interfiriera con las pruebas del profesor, entonces al final decidi no hacerlo (Brian).
