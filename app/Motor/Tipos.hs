-- Tipos del dominio del motor de aventuras. --

module Motor.Tipos
  ( -- Identificadores
    IdSala (..)      
  , IdObjeto (..)   
    -- Direcciones
  , Direccion (..)
  , todasLasDirecciones
  , nombreDireccion
  , direccionDeNombre
  , esIdentificador
    -- El mundo
  , Objeto (..)
  , Salida (..)
  , Sala (..)
  , Meta (..)
  , Mundo (..)
  , buscarSala
  , buscarObjeto
  , salidaEn
    -- Errores de lectura y validación
  , ErrorMundo (..)
  , describirError
    -- Juego en marcha
  , Comando (..)
  , Fin (..)
  , Estado (..)
  ) where


import Data.Map (Map)
import qualified Data.Map as Map

-- Identificadores

-- Identificador de sala. Es un newtype distinto del de objeto para que el
-- compilador no deje mezclarlos ya que las salas y los objetos tienen espacios de
-- nombres separados

-- El tipo NO garantiza que el texto sea un identificador válido eso lo comprueba 
-- el reconocedor al leer el archivo
newtype IdSala = IdSala String
  deriving (Eq, Ord, Show, Read)  

-- Identificador de objeto
newtype IdObjeto = IdObjeto String
  deriving (Eq, Ord, Show, Read)  

-- Direcciones

data Direccion = Norte | Sur | Este | Oeste | Arriba | Abajo
  deriving (Eq, Ord, Show, Read)  

-- Las seis direcciones, en el orden de la declaración
todasLasDirecciones :: [Direccion]
todasLasDirecciones = [Norte, Sur, Este, Oeste, Arriba, Abajo]

-- Cómo se escribe la dirección en el archivo y en los comandos
nombreDireccion :: Direccion -> String
nombreDireccion Norte  = "norte"
nombreDireccion Sur    = "sur"
nombreDireccion Este   = "este"
nombreDireccion Oeste  = "oeste"
nombreDireccion Arriba = "arriba"
nombreDireccion Abajo  = "abajo"

-- Inverso de nombreDireccion. Devuelve 'Nothing' si el texto no es una
-- dirección (no distingue mayúsculas)
direccionDeNombre :: String -> Maybe Direccion
direccionDeNombre txt = lookup txt [(nombreDireccion d, d) | d <- todasLasDirecciones]

-- Verifica si es un identificador válido de sala u objeto
esIdentificador :: String -> Bool
esIdentificador txt = not (null txt) && null (filter (not . valido) txt)
  where
    valido c = c `elem` ['a' .. 'z'] || c `elem` "áéíóúñü"
            || c `elem` ['0' .. '9'] || c == '_'

-- El mundo

data Objeto = Objeto
  { objetoId   :: IdObjeto, objetoDesc :: String } deriving (Eq, Show)

-- Una salida de una sala. Si salidaRequiere es 'Just o', solo se puede
-- cruzar llevando el objeto @o@ en el inventario.
data Salida = Salida
  { salidaDestino  :: IdSala , salidaRequiere :: Maybe IdObjeto } deriving (Eq, Show)

-- Una sala ya validada.

-- salaSalidas es un Map por dirección, así que el tipo garantiza que una
-- sala no tiene dos salidas en la misma dirección (V5). Por eso la duplicación
-- se detecta antes de construir el Map, mientras todavía son líneas del archivo.

-- salaObjetos son los objetos que hay en la sala al empezar, en el orden en
-- que aparecen en el archivo. Los cambios durante la partida los lleva el
-- Estado, no el mundo
data Sala = Sala
  { salaId      :: IdSala
  , salaDesc    :: String
  , salaSalidas :: Map Direccion Salida  
  , salaObjetos :: [IdObjeto]
  } deriving (Eq, Show)

-- La meta del mundo.
data Meta
  = LlegarA IdSala             -- se cumple al entrar en la sala
  | LlevarA IdObjeto IdSala    -- se cumple al estar en la sala con el objeto
  deriving (Eq, Show)

-- Un mundo completo. Solo lo produce leerMundo después de validar, así que
-- los Maps no tienen ids duplicados y la sala inicial existe
data Mundo = Mundo
  { mundoTitulo  :: String
  , mundoInicio  :: IdSala
  , mundoMeta    :: Meta
  , mundoTurnos  :: Int                   
  , mundoObjetos :: Map IdObjeto Objeto 
  , mundoSalas   :: Map IdSala Sala      
  } deriving (Eq, Show)

-- Busca una sala por su identificador
buscarSala :: IdSala -> Mundo -> Maybe Sala
buscarSala i m = Map.lookup i (mundoSalas m)

-- Busca un objeto por su identificador
buscarObjeto :: IdObjeto -> Mundo -> Maybe Objeto
buscarObjeto i m = Map.lookup i (mundoObjetos m)

-- La salida de una sala en una dirección, si existe
salidaEn :: Direccion -> Sala -> Maybe Salida
salidaEn d s = Map.lookup d (salaSalidas s)

-- Errores

-- Todos los errores que puede dar la lectura y validación del mundo
data ErrorMundo
  = ClaveDesconocida Int String
  | LineaMalFormada Int String
  | BloqueDesconocido Int String
  | CampoAusente Int String String
  | CampoRepetido Int String
  | SalidaMalFormada Int String
  | MetaMalFormada Int String
  | DireccionInexistente Int String
  | IdentificadorInvalido Int String
  | TurnosNoNumerico Int String
  | ErrorSintaxis Int String
  | SalaDuplicada IdSala
  | ObjetoDuplicado IdObjeto
  | SalidaASalaInexistente IdSala Direccion IdSala
  | RequisitoInexistente IdSala Direccion IdObjeto
  | DireccionRepetida IdSala Direccion
  | ObjetoNoDefinidoEnSala IdSala IdObjeto
  | ObjetoEnVariasSalas IdObjeto [IdSala]
  | InicioInexistente IdSala
  | MetaSalaInexistente IdSala
  | MetaObjetoInexistente IdObjeto
  | SalaInalcanzable IdSala
  | ObjetoInconseguible IdObjeto
  | TurnosInvalidos Int
  | TurnosInsuficientes Int Int
  deriving (Eq, Show)

-- Mensaje para el jugador
describirError :: ErrorMundo -> String
describirError (ClaveDesconocida n k) =
  enLinea n ("la clave '" ++ k ++ "' no existe")
describirError (LineaMalFormada n txt) =
  enLinea n ("no tiene la forma CLAVE: valor: " ++ txt)
describirError (BloqueDesconocido n k) =
  enLinea n ("un bloque no puede empezar con '" ++ k ++ "'; debe ser OBJETO o SALA")
describirError (CampoAusente n bloque k) =
  enLinea n ("falta el campo " ++ k ++ " en " ++ bloque)
describirError (CampoRepetido n k) =
  enLinea n ("el campo " ++ k ++ " aparece más de una vez")
describirError (SalidaMalFormada n txt) =
  enLinea n ("SALIDA mal formada: " ++ txt)
describirError (MetaMalFormada n txt) =
  enLinea n ("META mal formada: " ++ txt)
describirError (DireccionInexistente n txt) =
  enLinea n ("'" ++ txt ++ "' no es una dirección")
describirError (IdentificadorInvalido n txt) =
  enLinea n ("'" ++ txt ++ "' no es un identificador válido")
describirError (TurnosNoNumerico n txt) =
  enLinea n ("TURNOS debe ser un entero, no '" ++ txt ++ "'")
describirError (ErrorSintaxis n msg) =
  enLinea n msg
describirError (SalaDuplicada (IdSala s)) =
  "Error: la sala '" ++ s ++ "' está definida más de una vez"
describirError (ObjetoDuplicado (IdObjeto o)) =
  "Error: el objeto '" ++ o ++ "' está definido más de una vez"
describirError (SalidaASalaInexistente (IdSala s) d (IdSala t)) =
  "Error: la sala '" ++ s ++ "' tiene una salida al " ++ nombreDireccion d
    ++ " hacia la sala '" ++ t ++ "', que no existe"
describirError (RequisitoInexistente (IdSala s) d (IdObjeto o)) =
  "Error: la salida al " ++ nombreDireccion d ++ " de la sala '" ++ s
    ++ "' requiere el objeto '" ++ o ++ "', que no existe"
describirError (DireccionRepetida (IdSala s) d) =
  "Error: la sala '" ++ s ++ "' tiene dos salidas hacia el "
    ++ nombreDireccion d
describirError (ObjetoNoDefinidoEnSala (IdSala s) (IdObjeto o)) =
  "Error: la sala '" ++ s ++ "' contiene el objeto '" ++ o
    ++ "', que no está definido"
describirError (ObjetoEnVariasSalas (IdObjeto o) ss) =
  "Error: el objeto '" ++ o ++ "' está colocado más de una vez (salas: "
    ++ unirConComas [s | IdSala s <- ss] ++ ")"
describirError (InicioInexistente (IdSala s)) =
  "Error: INICIO apunta a la sala '" ++ s ++ "', que no existe"
describirError (MetaSalaInexistente (IdSala s)) =
  "Error: META menciona la sala '" ++ s ++ "', que no existe"
describirError (MetaObjetoInexistente (IdObjeto o)) =
  "Error: META menciona el objeto '" ++ o ++ "', que no existe"
describirError (SalaInalcanzable (IdSala s)) =
  "Error: la sala '" ++ s ++ "' no se puede alcanzar desde INICIO"
describirError (ObjetoInconseguible (IdObjeto o)) =
  "Error: el objeto '" ++ o ++ "' hace falta pero no está en ninguna sala"
describirError (TurnosInvalidos n) =
  "Error: TURNOS debe ser un entero positivo (se dio " ++ show n ++ ")"
describirError (TurnosInsuficientes minimo hay) =
  "Error: la meta necesita al menos " ++ show minimo
    ++ " turnos y el mundo solo da " ++ show hay

-- Prefijo común de los errores de sintaxis.
enLinea :: Int -> String -> String
enLinea n msg = "Error: línea " ++ show n ++ ": " ++ msg

unirConComas :: [String] -> String
unirConComas []       = ""
unirConComas [x]      = x
unirConComas (x : xs) = x ++ ", " ++ unirConComas xs

-- Manejador de comandos --
data Comando
  = Ir Direccion
  | Mirar
  | Tomar IdObjeto
  | Soltar IdObjeto
  | Examinar IdObjeto
  | Inventario
  | Guardar String
  | Cargar String
  | Ayuda
  | Salir
  deriving (Eq, Show)

-- Manejador de transiciones de estado --
data Fin
  = Continuar
  | Ganar
  | FinTurnos
  | Abandonar
  deriving (Eq, Show)


-- Estado de la partida --
data Estado = Estado
  { salaActual :: IdSala, 
    inventario :: [IdObjeto],
    objetosSala :: Map IdSala [IdObjeto],
    turnosRestantes :: Int
  } deriving (Eq, Show, Read)